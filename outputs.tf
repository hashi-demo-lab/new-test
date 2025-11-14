# Output Values

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = try(module.alb.dns_name, null)
}

output "alb_zone_id" {
  description = "Route53 zone ID of the Application Load Balancer"
  value       = try(module.alb.zone_id, null)
}

output "instance_ids" {
  description = "List of EC2 instance IDs"
  value = [
    try(module.ec2_instance_az1.id, null),
    try(module.ec2_instance_az2.id, null)
  ]
}

output "instance_private_ips" {
  description = "List of EC2 instance private IP addresses"
  value = [
    try(module.ec2_instance_az1.private_ip, null),
    try(module.ec2_instance_az2.private_ip, null)
  ]
}

output "alb_target_group_arns" {
  description = "ARNs of ALB target groups"
  value       = try(module.alb.target_groups, null)
}
