# --- BASTION ---
output "bastion_public_ip" { #ssh entry point
  description = "Public IP of the Bastion Host. Use this IP to SSH into the VPC."
  value       = module.compute.bastion_public_ip
}

output "bastion_private_ip" { #internal testing
  description = "Private IP of the Bastion Host. Useful for internal network verification."
  value       = module.compute.bastion_private_ip
}
# --- AUTO LOAD BALANCER ---
output "frontend_alb_dns" { #public DNS -> main test URl
  description = "Public DNS of the Frontend Load Balancer. This is your primary target for stress testing."
  value       = module.load_balancer.frontend_alb_dns
}

output "backend_nlb_dns" { #internal DNS -> test from Bastion
  description = "Internal DNS of the Backend Load Balancer. Use this to verify internal connectivity from the Bastion."
  value       = module.load_balancer.backend_lb_dns
}
# --- IPS ---
output "frontend_ips" {
  description = "Actual Private IPs of Frontend ASG Instances"
  value       = module.compute.frontend_instance_ips
}

output "backend_ips" {
  description = "Actual Private IPs of Backend ASG Instances"
  value       = module.compute.backend_instance_ips
}


