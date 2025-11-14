# Input Variables

variable "region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "ap-southeast-2"

  validation {
    condition     = var.region == "ap-southeast-2"
    error_message = "Region must be ap-southeast-2 (FR-001)."
  }
}

variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.small"

  validation {
    condition     = var.instance_type == "t3.small"
    error_message = "Instance type must be t3.small (FR-008)."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
  }
}
