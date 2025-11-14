# Data Model: EC2 ALB Infrastructure Components

**Feature**: EC2 Web Infrastructure with Application Load Balancer
**Date**: 2025-11-14

## Infrastructure Component Model

This document defines the infrastructure entities, their attributes, and relationships.

---

## Core Components

### 1. Compute Instance (EC2)

**Purpose**: Virtual machine running Nginx web server

**Attributes**:
- `instance_id` (string) - AWS EC2 instance ID
- `instance_type` (string) - "t3.small" (2 vCPU, 2 GB RAM)
- `ami_id` (string) - Amazon Linux 2023 AMI ID (from SSM parameter)
- `availability_zone` (string) - One of: "ap-southeast-2a", "ap-southeast-2b"
- `private_ip_address` (string) - VPC private IP
- `public_ip_address` (string, optional) - Public IP if in public subnet
- `subnet_id` (string) - VPC subnet ID
- `security_group_ids` (list) - List of security group IDs
- `iam_instance_profile_arn` (string) - IAM instance profile for AWS service access
- `user_data` (string) - Bash script for Nginx installation and configuration
- `state` (enum) - pending | running | stopping | stopped | terminated

**Relationships**:
- **BelongsTo** Subnet (1:1)
- **AttachedTo** SecurityGroup (1:N)
- **RegisteredWith** TargetGroup (1:1)
- **UsesProfile** IAMInstanceProfile (1:1)

**State Transitions**:
```
pending → running → [stopping → stopped] → terminated
```

**Validation Rules**:
- `instance_type` MUST be "t3.small" (FR-008)
- `availability_zone` MUST be in ["ap-southeast-2a", "ap-southeast-2b"] (FR-001)
- `user_data` MUST install Nginx and configure SSL
- MUST be registered to ALB target group

---

### 2. Application Load Balancer (ALB)

**Purpose**: Internet-facing traffic distribution across EC2 instances

**Attributes**:
- `load_balancer_arn` (string) - AWS ALB ARN
- `load_balancer_name` (string) - Human-readable name
- `dns_name` (string) - ALB DNS endpoint (e.g., nginx-alb-123456.ap-southeast-2.elb.amazonaws.com)
- `zone_id` (string) - Route53 hosted zone ID
- `scheme` (enum) - "internet-facing" (FR-003)
- `ip_address_type` (enum) - "ipv4" | "dualstack"
- `vpc_id` (string) - VPC ID
- `subnet_ids` (list) - List of subnet IDs (minimum 2 AZs)
- `security_group_ids` (list) - List of security group IDs
- `state` (enum) - provisioning | active | failed

**Relationships**:
- **DeployedIn** VPC (1:1)
- **SpansSubnets** Subnet (1:N, minimum 2)
- **ProtectedBy** SecurityGroup (1:N)
- **RoutesTo** TargetGroup (1:N)
- **Exposes** Listener (1:N)

**Validation Rules**:
- `scheme` MUST be "internet-facing" (clarification: ALB accessibility)
- `subnet_ids` MUST contain exactly 2 subnets from different AZs (FR-001)
- `subnet_ids` MUST be in ["ap-southeast-2a", "ap-southeast-2b"]

---

### 3. ALB Listener

**Purpose**: Protocol/port configuration for incoming traffic

**Attributes**:
- `listener_arn` (string) - AWS listener ARN
- `load_balancer_arn` (string) - Parent ALB ARN
- `protocol` (enum) - "HTTP" | "HTTPS"
- `port` (number) - 80 | 443
- `ssl_policy` (string, optional) - TLS policy (HTTPS only)
- `certificate_arn` (string, optional) - SSL certificate ARN (HTTPS only)
- `default_action` (object) - Routing action (forward, redirect, fixed-response)

**Relationships**:
- **BelongsTo** ApplicationLoadBalancer (N:1)
- **ForwardsTo** TargetGroup (1:1 in default action)

**Instances** (per spec clarifications):

1. **HTTP Listener**:
   - `protocol` = "HTTP"
   - `port` = 80
   - `default_action` = forward to Target Group "nginx_instances"

2. **HTTPS Listener** (future, not in initial MVP):
   - `protocol` = "HTTPS"
   - `port` = 443
   - `ssl_policy` = "ELBSecurityPolicy-TLS13-1-2-2021-06"
   - `certificate_arn` = Self-signed certificate ARN
   - `default_action` = forward to Target Group "nginx_instances"

**Validation Rules**:
- HTTP listener MUST forward to target group (FR-009)
- HTTPS listener (if configured) MUST use TLS 1.2+ policy
- HTTPS listener MUST have valid certificate_arn

---

### 4. Target Group

**Purpose**: Logical grouping of EC2 instances for load balancing

**Attributes**:
- `target_group_arn` (string) - AWS target group ARN
- `target_group_name` (string) - Human-readable name
- `protocol` (enum) - "HTTP" | "HTTPS"
- `port` (number) - Backend port (80)
- `vpc_id` (string) - VPC ID
- `target_type` (enum) - "instance" (vs "ip", "lambda")
- `health_check` (object) - Health check configuration:
  - `enabled` (bool) - true
  - `protocol` (enum) - "HTTP"
  - `port` (string) - "traffic-port" | specific port
  - `path` (string) - "/health" (FR-006)
  - `interval` (number) - 10 seconds (FR-006, NFR-003)
  - `timeout` (number) - 5 seconds (FR-006)
  - `healthy_threshold` (number) - 2 consecutive successes
  - `unhealthy_threshold` (number) - 2 consecutive failures (FR-006)
  - `matcher` (string) - "200" (HTTP success codes)

**Relationships**:
- **ContainsTargets** ComputeInstance (1:N)
- **RoutedFromListener** Listener (N:1)
- **PerformsHealthChecks** ComputeInstance (1:N)

**Validation Rules**:
- `health_check.interval` MUST be 10 seconds (FR-006)
- `health_check.timeout` MUST be 5 seconds (FR-006)
- `health_check.unhealthy_threshold` MUST be 2 (FR-006)
- `health_check.path` MUST be "/health"
- Detection time MUST be ≤30 seconds (NFR-003): `interval × unhealthy_threshold` = 10s × 2 = 20s ✓

---

### 5. Security Group

**Purpose**: Network access control (stateful firewall)

**Attributes**:
- `security_group_id` (string) - AWS security group ID
- `security_group_name` (string) - Human-readable name
- `description` (string) - Purpose description
- `vpc_id` (string) - VPC ID
- `ingress_rules` (list of objects):
  - `from_port` (number)
  - `to_port` (number)
  - `protocol` (string) - "tcp" | "udp" | "icmp" | "-1"
  - `cidr_blocks` (list, optional) - List of CIDR blocks
  - `source_security_group_id` (string, optional) - Referenced security group
  - `description` (string)
- `egress_rules` (list of objects) - Same structure as ingress

**Relationships**:
- **ProtectsResource** ComputeInstance | ApplicationLoadBalancer (1:N)
- **ReferencedBy** SecurityGroup (N:N for security group referencing)

**Instances**:

1. **ALB Security Group**:
   - Ingress: Allow 0.0.0.0/0:80,443 (HTTP/HTTPS from internet)
   - Egress: Allow all

2. **EC2 Security Group**:
   - Ingress: Allow ALB_SG:80,443 (security group referencing - FR-007)
   - Egress: Allow 0.0.0.0/0:443,80 (HTTPS/HTTP for package updates)
   - NO port 22 (SSH) - use Session Manager instead

**Validation Rules**:
- EC2 security group ingress MUST reference ALB security group (NOT CIDR blocks) (FR-007)
- EC2 security group MUST NOT allow 0.0.0.0/0 on ports 22, 80, 443
- ALB security group MUST allow 0.0.0.0/0:80,443 for internet access

---

### 6. IAM Instance Profile

**Purpose**: AWS service permissions for EC2 instances

**Attributes**:
- `instance_profile_arn` (string) - IAM instance profile ARN
- `instance_profile_name` (string) - Human-readable name
- `role_arn` (string) - Attached IAM role ARN
- `attached_policies` (list) - List of policy ARNs:
  - `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`
  - Custom CloudWatch Logs policy

**Relationships**:
- **AttachedToRole** IAMRole (1:1)
- **GrantsPermissionsTo** ComputeInstance (1:N)

**Permissions**:
1. **Session Manager Access** (AWS managed policy):
   - `ssm:UpdateInstanceInformation`
   - `ssmmessages:CreateControlChannel`
   - `ssmmessages:CreateDataChannel`
   - `ssmmessages:OpenControlChannel`
   - `ssmmessages:OpenDataChannel`

2. **CloudWatch Logs** (custom policy, scoped):
   - `logs:CreateLogGroup`
   - `logs:CreateLogStream`
   - `logs:PutLogEvents`
   - Resource: `arn:aws:logs:ap-southeast-2:*:log-group:/aws/ec2/nginx/*`

**Validation Rules**:
- MUST include `AmazonSSMManagedInstanceCore` (managed policy)
- CloudWatch permissions MUST be scoped to `/aws/ec2/nginx/*` log group
- MUST NOT include overly permissive policies (e.g., `AdministratorAccess`)

---

## Component Relationships Diagram

```
VPC (default)
  ├── Subnets (ap-southeast-2a, ap-southeast-2b)
  │     ├── ALB (internet-facing, spans both AZs)
  │     │    ├── Listener:80 (HTTP) → Target Group
  │     │    └── Security Group (allow 0.0.0.0/0:80,443)
  │     └── EC2 Instances (1 per AZ)
  │          ├── Security Group (allow ALB_SG:80,443)
  │          ├── IAM Instance Profile (Session Manager + CloudWatch)
  │          └── User Data (Nginx + SSL)
  └── Target Group
        ├── Health Check (HTTP:80/health, 10s interval, 5s timeout, 2 failures)
        └── Targets: EC2 Instance AZ1, EC2 Instance AZ2
```

---

## Data Flow

**User Request Flow**:
```
1. Internet User → ALB DNS (nginx-alb-*.ap-southeast-2.elb.amazonaws.com)
2. ALB receives request on Listener:80 (HTTP)
3. ALB checks Target Group health status
4. ALB forwards request to healthy EC2 instance (round-robin across AZs)
5. EC2 Nginx processes request on port 80
6. Nginx redirects to HTTPS:443 (per spec clarification: independent listeners)
7. Response returned via ALB to user
```

**Health Check Flow**:
```
1. ALB sends GET /health to EC2:80 every 10 seconds
2. Nginx returns HTTP 200 "healthy"
3. ALB marks target healthy after 2 consecutive successes
4. ALB marks target unhealthy after 2 consecutive failures (20s total)
5. ALB stops routing traffic to unhealthy targets within 60s (NFR-004)
```

**Failure Scenario (Instance Failure)**:
```
1. EC2 instance stops or Nginx crashes
2. ALB health check to /health fails
3. After 2 failures (20 seconds), ALB marks instance unhealthy
4. ALB routes 100% of traffic to remaining healthy instance
5. When instance recovers and passes 2 consecutive health checks, ALB adds it back
```

---

## Configuration Values

**Fixed Values** (from spec clarifications):
- Region: `ap-southeast-2`
- Instance Type: `t3.small`
- AZ Count: Exactly 2
- Health Check Interval: 10 seconds
- Health Check Timeout: 5 seconds
- Unhealthy Threshold: 2 failures
- ALB Scheme: `internet-facing`
- Target Protocol: HTTP (port 80)

**Variable Values** (environment-specific):
- VPC ID: Determined from default VPC data source
- Subnet IDs: Determined from default VPC subnets
- AMI ID: Determined from SSM parameter `/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64`
- Security Group IDs: Created during deployment

---

## Tags (Resource Metadata)

All resources MUST include standard tags (FR-010):

```hcl
{
  "Name"        = "<resource-specific-name>"
  "Environment" = "dev"
  "ManagedBy"   = "terraform"
  "Feature"     = "ec2-alb-nginx"
  "CostCenter"  = "<optional>"
}
```
