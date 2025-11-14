# EC2 Web Infrastructure with Application Load Balancer

Deploy high-availability web infrastructure using 2x t3.small EC2 instances across 2 availability zones in ap-southeast-2, fronted by an internet-facing Application Load Balancer.

## Features

- **High Availability**: Multi-AZ deployment across ap-southeast-2a and ap-southeast-2b
- **Load Balancing**: Internet-facing Application Load Balancer with health checks
- **Web Server**: Nginx with self-signed SSL certificates
- **Security**: Security group referencing, Session Manager access (no SSH), TLS 1.2+
- **Cost Optimized**: t3.small instances, ~$50/month for development environment

## Architecture

```
Internet → Application Load Balancer (ap-southeast-2a, ap-southeast-2b)
    ├── HTTP:80 Listener → Target Group → EC2 Instances
    └── HTTPS:443 Listener → Target Group → EC2 Instances
          ├── Instance 1 (ap-southeast-2a) - Nginx HTTP/HTTPS
          └── Instance 2 (ap-southeast-2b) - Nginx HTTP/HTTPS
```

## Prerequisites

- AWS Account with EC2, VPC, ELB, IAM permissions
- Default VPC in ap-southeast-2 region
- HCP Terraform: Organization `hashi-demos-apj`, Project `sandbox`
- Terraform >= 1.8
- Pre-commit framework

## Usage

```bash
# Install pre-commit hooks
pre-commit install

# Configure variables
cp sandbox.auto.tfvars.example sandbox.auto.tfvars

# Deploy via HCP Terraform (commit and push)
git add . && git commit -m "Add infrastructure" && git push

# Or use Terraform CLI
terraform init && terraform plan
```

## Security

- No SSH access (use AWS Session Manager)
- Security group referencing (EC2 accepts traffic only from ALB)
- TLS 1.2+ encryption
- Self-signed certificates (dev environment)

## Cost

~$50/month (2x t3.small + ALB + data transfer)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.21.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | app.terraform.io/hashi-demos-apj/alb/aws | ~> 10.1.0 |
| <a name="module_alb_security_group"></a> [alb\_security\_group](#module\_alb\_security\_group) | app.terraform.io/hashi-demos-apj/security-group/aws | ~> 5.3.1 |
| <a name="module_ec2_instance_az1"></a> [ec2\_instance\_az1](#module\_ec2\_instance\_az1) | app.terraform.io/hashi-demos-apj/ec2-instance/aws | ~> 6.1.4 |
| <a name="module_ec2_instance_az2"></a> [ec2\_instance\_az2](#module\_ec2\_instance\_az2) | app.terraform.io/hashi-demos-apj/ec2-instance/aws | ~> 6.1.4 |
| <a name="module_ec2_security_group"></a> [ec2\_security\_group](#module\_ec2\_security\_group) | app.terraform.io/hashi-demos-apj/security-group/aws | ~> 5.3.1 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.ec2_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.ec2_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.cloudwatch_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ssm_managed_instance_core](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_target_group_attachment.az1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_lb_target_group_attachment.az2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_ssm_parameter.amazon_linux_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_subnet.az1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnet.az2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_subnets.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_common_tags"></a> [common\_tags](#input\_common\_tags) | Common tags to apply to all resources | `map(string)` | <pre>{<br/>  "Environment": "dev"<br/>}</pre> | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment | `string` | `"dev"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type for web servers | `string` | `"t3.small"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region for infrastructure deployment | `string` | `"ap-southeast-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer |
| <a name="output_alb_target_group_arns"></a> [alb\_target\_group\_arns](#output\_alb\_target\_group\_arns) | ARNs of ALB target groups |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Route53 zone ID of the Application Load Balancer |
| <a name="output_instance_ids"></a> [instance\_ids](#output\_instance\_ids) | List of EC2 instance IDs |
| <a name="output_instance_private_ips"></a> [instance\_private\_ips](#output\_instance\_private\_ips) | List of EC2 instance private IP addresses |
<!-- END_TF_DOCS -->
