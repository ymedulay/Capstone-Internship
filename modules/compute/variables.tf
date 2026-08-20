variable "instance_config" { 
  type        = map(string) #all string values
  description = "Configuration for EC2 instances"
  default     = {
    bastion = "t2.micro"
    asg     = "t3.micro"
    key     = "dulay-keypair"
    ami_ptr = "al2023-ami-2023.*-x86_64"
    owner   = "amazon"
  }
}

variable "asg_settings" { 
  type        = map(any) #value types are mixed
  description = "Auto Scaling Group sizing and behavior"
  default     = {
    min           = 2
    max           = 4
    desired       = 2
    hc_type       = "ELB"
    adj_type      = "ChangeInCapacity" #increase or decrease by a specific number
    policy_type   = "SimpleScaling" #used to automatically adjust the number of instances in an Auto Scaling Group based on a single, static scaling adjustment after a CloudWatch alarm is breached.
    scale_out_val = 1
    scale_in_val  = -1
    cpu_high      = 40
    cpu_low       = 10
    alarm_stat    = "Average"
    alarm_period  = 60
  }
}

variable "cw_alarm_config" {
  type = object({ #value types are mixed but prevents missing keys
    metric_name = string
    namespace   = string
  })
  description = "CloudWatch alarm metric configuration"
  default = {
    metric_name = "CPUUtilization"
    namespace   = "AWS/EC2" #tells tf where to look
  }
}

variable "cw_comparison_operators" {
  type = object({
    scale_out = string
    scale_in  = string
  })
  description = "Comparison operators for scale in and scale out"
  default = {
    scale_out = "GreaterThanOrEqualToThreshold"
    scale_in  = "LessThanOrEqualToThreshold"
  }
}

variable "cw_metric_dimensions" { 
  type        = string 
  description = "CloudWatch dimension key for Auto Scaling Group"
  default     = "AutoScalingGroupName"
}

variable "instance_refresh_config" {
  description = "Configuration for ASG rolling updates"
  type = object({ #multiple fields, stricty typing, rolling update parameters
    strategy = string
    min_healthy_percentage = number
    warmup = number
  })
  default = {
    strategy = "Rolling" #replaces instances gradually
    min_healthy_percentage = 50 #keeps at least 1 instance running during update
    warmup = 30
  }
}

# Parameters passed from other modules or root logic
variable "vpc_id" { 
  type = string 
}
variable "public_subnet_id" { 
  type = string 
}
variable "private_subnet_ids" { 
  type = list(string) 
}
variable "bastion_sg_id" { 
  type = string 
}
variable "frontend_sg_id" { 
  type = string 
}
variable "backend_sg_id" { 
  type = string 
}
variable "frontend_tg_arn" { 
  type = string 
}
variable "backend_tg_arn" { 
  type = string 
}
variable "backend_lb_dns" { 
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