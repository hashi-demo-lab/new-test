# Research: EC2 ALB Infrastructure

**Date**: 2025-11-14
**Feature**: [EC2 Web Infrastructure with Application Load Balancer](./spec.md)

## Executive Summary

All required Terraform modules found in `hashi-demos-apj` private registry. Security architecture follows AWS Well-Architected Framework. Nginx user data pattern validated for Amazon Linux 2023.

## Module Research Results

### EC2 Instance Module (app.terraform.io/hashi-demos-apj/ec2-instance/aws v6.1.4)

**Capabilities**: User data, IAM instance profile creation, IMDSv2 enforcement, target group attachment

**Key Inputs**:
- `instance_type`, `ami_ssm_parameter`, `subnet_id`, `vpc_security_group_ids`
- `user_data`, `iam_instance_profile`, `create_iam_instance_profile`
- `target_group_arns` (for ALB attachment)

**Key Outputs**: `id`, `arn`, `private_ip`, `public_ip`, `availability_zone`

### ALB Module (app.terraform.io/hashi-demos-apj/alb/aws v10.1.0)

**Capabilities**: Auto security group creation, HTTP/HTTPS listeners, target groups, health check configuration

**Key Inputs**:
- `subnets`, `vpc_id`, `internal` (default: false = internet-facing)
- `listeners` (map), `target_groups` (map)
- `security_groups`, `security_group_ingress_rules`

**Key Outputs**: `dns_name`, `zone_id`, `target_groups`, `security_group_id`

### Security Group Module (app.terraform.io/hashi-demos-apj/security-group/aws v5.3.1)

**Capabilities**: Named rules, custom rules, security group referencing

**Key Inputs**:
- `vpc_id`, `name`, `description`
- `ingress_with_cidr_blocks`, `ingress_with_source_security_group_id`
- `egress_with_cidr_blocks`

**Key Outputs**: `security_group_id`, `security_group_arn`

---

## AWS Security Best Practices

### Security Group Architecture

**ALB Security Group**:
```
Ingress: 0.0.0.0/0:80,443 (HTTP/HTTPS from internet)
Egress: ALL (to EC2 instances via security group reference)
```

**EC2 Security Group**:
```
Ingress: ALB_SG:80,443 (HTTP/HTTPS from ALB only - security group referencing)
Egress: 0.0.0.0/0:443,80 (HTTPS/HTTP for package updates)
NO Port 22 (SSH) - use Systems Manager Session Manager instead
```

### IAM Instance Profile

**Required Policies**:
1. `AmazonSSMManagedInstanceCore` (AWS managed) - Session Manager access
2. CloudWatch Logs (custom policy):
```json
{
  "Effect": "Allow",
  "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
  "Resource": "arn:aws:logs:ap-southeast-2:*:log-group:/aws/ec2/nginx/*"
}
```

### TLS Configuration

**ALB HTTPS Listener**:
- Policy: `ELBSecurityPolicy-TLS13-1-2-2021-06` (TLS 1.2/1.3 only)
- Certificate: Self-signed (development) or ACM (production)

**Nginx SSL**:
- Protocols: TLSv1.2, TLSv1.3
- Ciphers: HIGH:!aNULL:!MD5

---

## Nginx User Data Script

**Approach**: Bash script with comprehensive error handling

**Script Structure**:
```bash
#!/bin/bash
set -e  # Exit on error
exec > >(tee -a /var/log/user-data.log) 2>&1  # Logging

# 1. Update packages (dnf update -y)
# 2. Install Nginx (dnf install nginx -y)
# 3. Create SSL directory (/etc/nginx/ssl)
# 4. Generate self-signed certificate (OpenSSL, 365 days)
# 5. Configure Nginx (HTTP:80 + HTTPS:443)
# 6. Start and enable Nginx service
# 7. Verify service is running
```

**Nginx Configuration**:
```nginx
# HTTP Server (Port 80)
server {
    listen 80 default_server;
    location /health {
        return 200 "healthy\n";
    }
    location / {
        return 301 https://$host$request_uri;  # Redirect to HTTPS
    }
}

# HTTPS Server (Port 443)
server {
    listen 443 ssl http2 default_server;
    ssl_certificate /etc/nginx/ssl/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx-selfsigned.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location /health {
        return 200 "healthy\n";
    }
    location / {
        try_files $uri $uri/ =404;
    }
}
```

**Health Check Configuration**:
- Target: `HTTP:80/health`
- Interval: 10 seconds
- Timeout: 5 seconds
- Unhealthy threshold: 2 consecutive failures
- Detection time: 20 seconds worst case (meets NFR-003: <30s)

---

## Technology Decision Matrix

| Decision | Selected | Rationale |
|----------|----------|-----------|
| **Instance Type** | t3.small | User clarification, 2 vCPU/2GB suitable for Nginx |
| **SSL Strategy** | Self-signed certificates | User clarification, acceptable for dev |
| **HTTP Behavior** | Independent listeners | User clarification, testing flexibility |
| **Health Check** | 10s/5s/2 | Meets 30s detection (NFR-003) with margin |
| **ALB Scheme** | Internet-facing | User clarification, public access required |
| **Nginx Install** | User data bash script | Fast iteration, comprehensive logging |
| **Cert Validity** | 365 days | Balance convenience/security for dev |
| **Health Endpoint** | HTTP:80 /health | Avoids SSL overhead, simpler debugging |
| **Subnet Strategy** | Public (default VPC) | Cost optimization, no NAT Gateway |

---

## Cost Estimate

**Monthly Infrastructure Costs** (ap-southeast-2):
- 2x t3.small instances: ~$30-35/month (730 hours × $0.0218/hour)
- 1x Application Load Balancer: ~$16-18/month ($0.0225/hour + $0.008/LCU)
- Data transfer OUT: ~$1-2/month (1GB free tier)
- **Total**: ~$47-55/month

**Optional Monitoring** (additional):
- VPC Flow Logs: ~$5-15/month
- ALB Access Logs (S3): ~$2-5/month
- CloudWatch alarms: Free (first 10 alarms)

**Total with monitoring**: ~$54-75/month

---

## References

**Private Module Registry**:
- EC2: https://app.terraform.io/app/hashi-demos-apj/registry/modules/private/hashi-demos-apj/ec2-instance/aws
- ALB: https://app.terraform.io/app/hashi-demos-apj/registry/modules/private/hashi-demos-apj/alb/aws
- Security Group: https://app.terraform.io/app/hashi-demos-apj/registry/modules/private/hashi-demos-apj/security-group/aws

**AWS Documentation**:
- [Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/security-group-rules.html)
- [ALB TLS Policies](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/describe-ssl-policies.html)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)
- [Well-Architected Framework - Security](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/)
