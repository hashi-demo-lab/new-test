provider "aws" {
  region = var.region

  # Short-lived dynamic credentials provided automatically
  # via pre-configured workspace variable sets
  # DO NOT add static credentials here
}
