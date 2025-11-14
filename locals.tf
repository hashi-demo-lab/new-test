locals {
  # Common resource tags (FR-010)
  common_tags = merge(
    var.common_tags,
    {
      Application = "EC2 ALB Nginx"
      Feature     = "ec2-alb-nginx"
      ManagedBy   = "terraform"
      Repository  = "https://github.com/<org>/<repo>" # Update with actual repo
    }
  )

  # Naming prefix
  name_prefix = "${var.environment}-nginx"
}
