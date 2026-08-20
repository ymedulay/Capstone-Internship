# Mechanics: This uses a 'for' loop to create a map of all physical AWS IDs

output "sg_ids" {
  description = "A map of all security group IDs indexed by their key in sg_configs"
  # This allows the root module to find any ID (like ALB-SG) by its easy-to-read name.
  value = { for k, v in aws_security_group.this : k => v.id }
}