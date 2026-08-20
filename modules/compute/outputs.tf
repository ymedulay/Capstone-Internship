#compute module outputs only runtime endpoints required for operations and validation 

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "selected_ami_id" {
  value = data.aws_ami.amazon_linux.id
}

#----
output "frontend_instance_ips" {
  description = "Private IPs of the Frontend instances"
  value       = data.aws_instances.frontend_instances.private_ips
}

output "backend_instance_ips" {
  description = "Private IPs of the Backend instances"
  value       = data.aws_instances.backend_instances.private_ips
}