#load balancer module manages traffic ingress, routing, health checks, and service-to-service connectivity between tiers

# --- FRONTEND ---
#provisions an external ALB to act as the single entry point for all web traffic
resource "aws_lb" "frontend_alb" {
  name               = "${var.name_prefix}-FrontendALB"
  load_balancer_type = var.network_config["lb_app"] #operates at Layer 7 to inspect and route HTTP/HTTPS requests
  security_groups    = [var.alb_sg_id] #controls which IPs/ports can reach the balancer's public interface
  subnets            = var.public_subnet_ids #distributes the balancer across multiple AZs for high availability
  tags               = merge(var.common_tags, { Name = "${var.name_prefix}-FrontendALB" })
}

#The group performs the health checks. 
#If a specific server inside the group fails, the group logically removes it from rotation so the Load Balancer stops sending it traffic
resource "aws_lb_target_group" "frontend_tg" {
  name        = "${var.name_prefix}-FrontendTG"
  port        = var.service_ports["http"] #(80) -> the port instances are listening on for incoming requests
  protocol    = var.network_config["http_proto"] #(HTTP) -> standard proto for web-based instance communication
  vpc_id      = var.vpc_id
  target_type = var.network_config["target_inst"] #routes traffic to private IP addresses of EC2 instances

  health_check {
    enabled = true
    path    = var.network_config["health_path"] #the specific URL path the LB pings to check server life
    matcher = var.network_config["matcher_code"] #expected successful HTTP status (200 ok) to keep the instance in rotation
  }
  tags = merge(var.common_tags, { Name = "${var.name_prefix}-FrontendTG" })
}

#evaluates incoming connection requests
resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = var.service_ports["http"] #80
  protocol          = var.network_config["http_proto"]#http
  default_action {
    type             = "forward" #directly forwards the client request to the TG w/o modification
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# --- BACKEND ---
#provisions an internal NLB for ultra-low latency between the web and app layers
resource "aws_lb" "backend_nlb" {
  name               = "${var.name_prefix}-BackendNLB"
  internal           = true #restricts traffic to the internal VPC network only
  load_balancer_type = var.network_config["lb_net"] #operates at Layer 4 (TCP) for high throughput and static IP support
  subnets            = var.private_subnet_ids #keeps backend communication isolated within private subnets
  tags               = merge(var.common_tags, { Name = "${var.name_prefix}-BackendNLB" })
}

#logical grouping for internal backend services
resource "aws_lb_target_group" "backend_tg" {
  name        = "${var.name_prefix}-BackendTG"
  port        = var.service_ports["http"]
  protocol    = var.network_config["tcp_u_proto"] #uses raw TCP for direct, fast communication between services
  vpc_id      = var.vpc_id
  target_type = var.network_config["target_inst"]
  tags        = merge(var.common_tags, { Name = "${var.name_prefix}-BackendTG" })
}

#listens for internal requests on the VPC network to route to the backend layer
resource "aws_lb_listener" "backend_listener" {
  load_balancer_arn = aws_lb.backend_nlb.arn
  port              = var.service_ports["http"] #port 80 bc of we are installing Apache httpd 
  protocol          = var.network_config["tcp_u_proto"]
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}