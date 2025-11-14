# Quick Start Guide: EC2 ALB Infrastructure Deployment

**Feature**: EC2 Web Infrastructure with Application Load Balancer
**Date**: 2025-11-14
**Target Environment**: Development (ap-southeast-2)

## Overview

This guide provides rapid deployment instructions for the EC2 ALB Nginx infrastructure using HCP Terraform. Estimated deployment time: **10 minutes**.

---

## Prerequisites

### Required Access

- [x] AWS Account with permissions for EC2, VPC, ELB, IAM services
- [x] HCP Terraform access to organization `hashi-demos-apj`
- [x] GitHub repository access for VCS integration
- [x] Default VPC exists in ap-southeast-2 region

### Required Tools

- [x] Terraform CLI >= 1.8 (for local testing)
- [x] AWS CLI configured (optional, for verification)
- [x] Git CLI
- [x] Pre-commit framework

### Environment Variables

```bash
# HCP Terraform authentication
export TFE_TOKEN="<your-terraform-cloud-token>"

# AWS credentials (configured via HCP Terraform workspace variables)
# DO NOT set these locally - use workspace variable sets
```

---

## Deployment Workflow

### Phase 1: Repository Setup

1. **Clone repository and checkout feature branch**:
   ```bash
   git clone <repository-url>
   cd <repository-name>
   git checkout 001-ec2-alb-nginx
   ```

2. **Install pre-commit hooks**:
   ```bash
   pre-commit install
   pre-commit run --all-files
   ```

### Phase 2: HCP Terraform Workspace Configuration

**Workspace Details**:
- **Organization**: `hashi-demos-apj`
- **Project**: `sandbox`
- **Workspace**: `sandbox_ec2new-test`
- **Execution Mode**: Remote
- **Auto-Apply**: Disabled (manual approval required)
- **VCS Integration**: Connected to `001-ec2-alb-nginx` branch

**Required Workspace Variables** (to be configured during implementation):

| Variable | Type | Sensitivity | Example Value | Description |
|----------|------|-------------|---------------|-------------|
| `environment` | Terraform | No | `dev` | Deployment environment |
| `common_tags` | Terraform (map) | No | `{"Environment" = "dev", "ManagedBy" = "terraform"}` | Common resource tags |
| `AWS_ACCESS_KEY_ID` | Environment | Yes | (from variable set) | AWS authentication |
| `AWS_SECRET_ACCESS_KEY` | Environment | Yes | (from variable set) | AWS authentication |

*Note: AWS credentials should be configured via HCP Terraform variable sets at the project/organization level, not workspace-level.*

### Phase 3: Ephemeral Testing Workspace

Before deploying to the sandbox workspace, validate code in an ephemeral testing workspace:

1. **Create ephemeral workspace** (automated via MCP tools):
   - Name: `test-ec2-alb-nginx-<timestamp>`
   - Auto-apply: Enabled
   - Auto-destroy: 2 hours

2. **Run validation tests**:
   ```bash
   terraform init
   terraform validate
   terraform plan
   ```

3. **Apply and verify**:
   - Monitor HCP Terraform run status
   - Verify infrastructure creation
   - Test ALB endpoint accessibility

4. **Cleanup**:
   - Trigger destroy operation
   - Confirm ephemeral workspace deletion

### Phase 4: Sandbox Deployment

1. **Review terraform plan** in HCP Terraform UI:
   - Navigate to workspace `sandbox_ec2new-test`
   - Review planned infrastructure changes
   - Verify resource count and configuration

2. **Approve and apply**:
   - Click "Confirm & Apply" in HCP Terraform UI
   - Monitor apply progress (estimated: 5-7 minutes)
   - Wait for "Apply finished" status

3. **Retrieve outputs**:
   ```bash
   # Via Terraform CLI
   terraform output

   # Expected outputs:
   # alb_dns_name = "nginx-alb-123456.ap-southeast-2.elb.amazonaws.com"
   # alb_zone_id = "Z1GM3OXH4ZPM65"
   # instance_ids = ["i-0123456789abcdef0", "i-0fedcba9876543210"]
   ```

---

## Verification & Testing

### Test 1: ALB Accessibility

```bash
# Get ALB DNS name from Terraform outputs
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTP access
curl http://${ALB_DNS}/

# Expected: 301 redirect to HTTPS or content served (depending on listener config)
```

### Test 2: Health Check Validation

```bash
# Test health endpoint
curl http://${ALB_DNS}/health

# Expected: HTTP 200 "healthy"
```

### Test 3: HTTPS Access (if HTTPS listener configured)

```bash
# Test HTTPS (with self-signed certificate warning)
curl -k https://${ALB_DNS}/

# Expected: Content served over HTTPS (browser warnings expected)
```

### Test 4: Multi-AZ Traffic Distribution

```bash
# Make multiple requests and observe X-Forwarded-For headers
for i in {1..10}; do
  curl -s http://${ALB_DNS}/ -I | grep -i server
done

# Expected: Responses distributed across both AZ instances
```

### Test 5: Failover Testing

1. **Stop one EC2 instance via AWS Console**
2. **Wait 20 seconds** (health check detection time)
3. **Verify traffic routes to healthy instance**:
   ```bash
   curl http://${ALB_DNS}/
   # Expected: Successful response from remaining instance
   ```
4. **Restart stopped instance**
5. **Wait 20 seconds** (health check recovery)
6. **Verify traffic distribution resumes**

---

## Cost Monitoring

**Expected Monthly Costs** (ap-southeast-2):

| Resource | Quantity | Unit Cost | Monthly Cost |
|----------|----------|-----------|--------------|
| EC2 t3.small | 2 instances | $0.0218/hour | ~$32 |
| Application Load Balancer | 1 ALB | $0.0225/hour + $0.008/LCU | ~$17 |
| Data Transfer OUT | ~1GB/month | $0.114/GB | ~$1 |
| **Total** | | | **~$50/month** |

**Cost Optimization Tips**:
- Use public subnets (avoids NAT Gateway: ~$32/month savings)
- Schedule instance stop/start for non-business hours (development only)
- Monitor CloudWatch metrics for rightsizing opportunities

---

## Troubleshooting

### Issue: Terraform plan shows no changes after code updates

**Cause**: Using local execution mode instead of HCP Terraform cloud backend.

**Fix**:
```bash
# Ensure terraform block includes cloud configuration
cat << 'EOF' > override.tf
terraform {
  cloud {
    organization = "hashi-demos-apj"
    workspaces {
      name    = "sandbox_ec2new-test"
      project = "sandbox"
    }
  }
}
EOF

# Re-run plan
terraform init
terraform plan
```

### Issue: Health checks failing after deployment

**Cause**: Nginx not installed or health endpoint not configured.

**Fix**:
1. Connect to instance via Session Manager:
   ```bash
   aws ssm start-session --target <instance-id>
   ```
2. Check Nginx status:
   ```bash
   sudo systemctl status nginx
   ```
3. Review user data logs:
   ```bash
   sudo cat /var/log/user-data.log
   ```

### Issue: "Permission denied (publickey)" during git operations

**Cause**: SSH key not configured for GitHub authentication.

**Fix**:
```bash
# Use HTTPS instead of SSH
git remote set-url origin https://github.com/<org>/<repo>.git

# Or configure SSH key
ssh-keygen -t ed25519 -C "your_email@example.com"
# Add public key to GitHub settings
```

### Issue: Pre-commit hooks failing with "command not found"

**Cause**: Pre-commit framework not installed.

**Fix**:
```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

---

## Cleanup

### Destroy Infrastructure

```bash
# Option 1: Via HCP Terraform UI
# Navigate to workspace → Settings → Destruction and Deletion → Queue destroy plan

# Option 2: Via Terraform CLI
terraform destroy -auto-approve

# Verify destruction
terraform show
# Expected: No resources exist
```

### Delete Ephemeral Workspaces

Ephemeral workspaces auto-destroy after 2 hours, but manual cleanup is recommended:

```bash
# Via HCP Terraform UI
# Navigate to workspace → Settings → Destruction and Deletion → Delete workspace

# Confirm no resources remain before deletion
```

---

## Next Steps

After successful deployment:

1. **Document deployment results** in `deployment_log_<timestamp>.log`
2. **Run security validation** using code-quality-judge subagent
3. **Create pull request** for feature branch review
4. **Schedule cost review** after 7 days of operation
5. **Plan production migration** (if applicable)

---

## References

- **Specification**: [spec.md](./spec.md)
- **Technical Plan**: [plan.md](./plan.md)
- **Data Model**: [data-model.md](./data-model.md)
- **Research Findings**: [research.md](./research.md)

**Support**: Contact infrastructure team via Slack #terraform-support
