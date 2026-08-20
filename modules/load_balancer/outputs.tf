#resource ARNs and DNS name exported for cross-module connectivity

# The unique Amazon Resource Name for the Frontend Target Group
# Mechanics: Used by the Frontend Auto Scaling Group to know where to register its instances
output "frontend_tg_arn" { 
    value = aws_lb_target_group.frontend_tg.arn 
}

# The unique Amazon Resource Name for the Backend Target Group
# Mechanics: Used by the Backend Auto Scaling Group to register internal logic servers
output "backend_tg_arn" { 
    value = aws_lb_target_group.backend_tg.arn 
}

# The internal DNS name of the Network Load Balancer
# Mechanics: Injected into Frontend userdata so web servers can locate the backend tier
output "backend_lb_dns" { 
    value = aws_lb.backend_nlb.dns_name 
}

# The public DNS name of the Application Load Balancer
# Mechanics: This is the final URL provided to the user to access the web application
output "frontend_alb_dns" { 
    value = aws_lb.frontend_alb.dns_name 
}