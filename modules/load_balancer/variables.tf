#standardized ports used to ensure consistent network configuration across tiers
variable "service_ports" { 
  type        = map(number) 
  description = "Map of service ports"
  default     = {
    ssh  = 22 #port for secure shell mngmt
    http = 80 #standard port for unencrypted web traffic
    any  = 0 #wildcardp ort for 'all traffic' egress rules
  }
}

#centralized technical constants
variable "network_config" { 
  type        = map(string) 
  description = "Network constants and protocol definitions"
  default     = {
    all_ips      = "0.0.0.0/0" #CIDR block representing the entire internet
    tcp_proto    = "tcp" #protocol string for standard TCP resources
    any_proto    = "-1" #AWS-specific code for 'all protocols'
    http_proto   = "HTTP" #Layer 7 ALB
    tcp_u_proto  = "TCP" #Layer 4 NLB
    lb_app       = "application" #identifies the balancer as ALB
    lb_net       = "network" #identifies the balancer as NLB
    target_inst  = "instance" #instructs the TG to route traffic to ec2 instance IDs
    health_path  = "/" #default root URL the LB pings to verify instance health
    matcher_code = "200" #HTTP status code indicating a successful health check
  }
}

#dynamic inputs provided by the root module to link the LB to the active environment
variable "vpc_id" { 
    type = string 
}
variable "public_subnet_ids" { 
    type = list(string) 
}
variable "private_subnet_ids" { 
    type = list(string)
}
variable "alb_sg_id" { 
    type = string 
}
variable "name_prefix" { 
    type = string 
}
variable "common_tags" { 
  type    = map(string)
  default = {
    ProjectCode = "Terraform101-CloudIntern"
  }
}