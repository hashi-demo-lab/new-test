# Main Infrastructure Configuration
# Feature: EC2 Web Infrastructure with Application Load Balancer

# ============================================================================
# DATA SOURCES
# ============================================================================

# Default VPC in ap-southeast-2 region (FR-002)
data "aws_vpc" "default" {
  default = true
}

# Default VPC subnets in specified availability zones (FR-001)
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-southeast-2a", "ap-southeast-2b"]
  }
}

# Get individual subnet details for each AZ
data "aws_subnet" "az1" {
  id = data.aws_subnets.default.ids[0]
}

data "aws_subnet" "az2" {
  id = data.aws_subnets.default.ids[1]
}

# Latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================

# ALB Security Group - Allow HTTP/HTTPS from internet (FR-007)
module "alb_security_group" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "~> 5.3.1"

  vpc_id      = data.aws_vpc.default.id
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for internet-facing ALB - allows HTTP/HTTPS from internet"

  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP from internet"
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS from internet"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
      description = "All outbound traffic"
    }
  ]

  tags = local.common_tags
}

# EC2 Security Group - Allow traffic only from ALB (FR-007, security group referencing)
module "ec2_security_group" {
  source  = "app.terraform.io/hashi-demos-apj/security-group/aws"
  version = "~> 5.3.1"

  vpc_id      = data.aws_vpc.default.id
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for EC2 Nginx instances - allows traffic from ALB only"

  ingress_with_source_security_group_id = [
    {
      from_port                = 80
      to_port                  = 80
      protocol                 = "tcp"
      source_security_group_id = module.alb_security_group.security_group_id
      description              = "HTTP from ALB"
    },
    {
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      source_security_group_id = module.alb_security_group.security_group_id
      description              = "HTTPS from ALB"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTPS for package updates and AWS APIs"
    },
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
      description = "HTTP for package repositories"
    }
  ]

  tags = local.common_tags
}

# ============================================================================
# APPLICATION LOAD BALANCER
# ============================================================================

# Internet-facing ALB with HTTP listener and target group (FR-003, FR-006, FR-009)
module "alb" {
  source  = "app.terraform.io/hashi-demos-apj/alb/aws"
  version = "~> 10.1.0"

  name    = "${local.name_prefix}-alb"
  vpc_id  = data.aws_vpc.default.id
  subnets = [data.aws_subnet.az1.id, data.aws_subnet.az2.id]

  internal                   = false # Internet-facing (FR-003)
  enable_deletion_protection = false # Development environment

  security_groups = [module.alb_security_group.security_group_id]

  # HTTP Listener (port 80) - FR-009: independent HTTP/HTTPS listeners
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "nginx_instances"
      }
    }
  }

  # Target Group with health check configuration (FR-006)
  target_groups = {
    nginx_instances = {
      name_prefix       = "nginx-"
      protocol          = "HTTP"
      port              = 80
      target_type       = "instance"
      create_attachment = false # Managed by separate aws_lb_target_group_attachment resources

      health_check = {
        enabled             = true
        interval            = 10 # FR-006: 10 second interval
        timeout             = 5  # FR-006: 5 second timeout
        healthy_threshold   = 2
        unhealthy_threshold = 2 # FR-006: 2 consecutive failures
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
      }

      deregistration_delay = 30 # NFR-004: Remove failed instances quickly
    }
  }

  tags = local.common_tags
}

# ============================================================================
# IAM INSTANCE PROFILE
# ============================================================================

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach AWS managed policy for Session Manager (no SSH required)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy for CloudWatch Logs (scoped to /aws/ec2/nginx/*)
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${local.name_prefix}-cloudwatch-logs"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/ec2/nginx/*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = local.common_tags
}

# ============================================================================
# EC2 INSTANCES
# ============================================================================

# EC2 Instance in AZ1 (ap-southeast-2a) - FR-001, FR-004, FR-008
module "ec2_instance_az1" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "~> 6.1.4"

  name          = "${local.name_prefix}-az1"
  instance_type = var.instance_type # t3.small per FR-008

  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  subnet_id              = data.aws_subnet.az1.id
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]

  # IAM instance profile for Session Manager and CloudWatch
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # User data script to install and configure Nginx (FR-004)
  user_data = templatefile("${path.module}/user_data.sh", {
    environment = var.environment
  })

  # Enable detailed monitoring
  monitoring = true

  tags = merge(local.common_tags, {
    Name             = "${local.name_prefix}-az1"
    AvailabilityZone = "ap-southeast-2a"
  })
}

# EC2 Instance in AZ2 (ap-southeast-2b) - FR-001, FR-004, FR-008
module "ec2_instance_az2" {
  source  = "app.terraform.io/hashi-demos-apj/ec2-instance/aws"
  version = "~> 6.1.4"

  name          = "${local.name_prefix}-az2"
  instance_type = var.instance_type # t3.small per FR-008

  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  subnet_id              = data.aws_subnet.az2.id
  vpc_security_group_ids = [module.ec2_security_group.security_group_id]

  # IAM instance profile for Session Manager and CloudWatch
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # User data script to install and configure Nginx (FR-004)
  user_data = templatefile("${path.module}/user_data.sh", {
    environment = var.environment
  })

  # Enable detailed monitoring
  monitoring = true

  tags = merge(local.common_tags, {
    Name             = "${local.name_prefix}-az2"
    AvailabilityZone = "ap-southeast-2b"
  })
}

# ============================================================================
# TARGET GROUP ATTACHMENTS
# ============================================================================

# Attach EC2 instance AZ1 to ALB target group
resource "aws_lb_target_group_attachment" "az1" {
  target_group_arn = module.alb.target_groups["nginx_instances"].arn
  target_id        = module.ec2_instance_az1.id
  port             = 80
}

# Attach EC2 instance AZ2 to ALB target group
resource "aws_lb_target_group_attachment" "az2" {
  target_group_arn = module.alb.target_groups["nginx_instances"].arn
  target_id        = module.ec2_instance_az2.id
  port             = 80
}
