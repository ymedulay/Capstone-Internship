# Standardized ports used to maintain consistency across all SG definitions
variable "service_ports" { 
  type        = map(number) 
  description = "Map of service ports"
  default     = {
    ssh  = 22
    http = 80
    any  = 0
  }
}

variable "network_config" { 
  type        = map(string) 
  description = "Network constants and protocol definitions"
  default     = {
    all_ips      = "0.0.0.0/0"
    tcp_proto    = "tcp"
    any_proto    = "-1"
    http_proto   = "HTTP"
    tcp_u_proto  = "TCP"
    lb_app       = "application"
    lb_net       = "network"
    target_inst  = "instance"
    health_path  = "/"
    matcher_code = "200"
  }
}

variable "vpc_id" { 
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

variable "sg_configs" { 
  type        = any 
  description = "Configuration for all security groups"
}