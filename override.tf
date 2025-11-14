# HCP Terraform Cloud Backend Configuration
# This file configures the Terraform Cloud backend for testing
# in the sandbox project using the sandbox workspace

terraform {
  cloud {
    organization = "hashi-demos-apj"

    workspaces {
      name    = "sandbox_ec2new-test"
      project = "sandbox"
    }
  }
}
