variable "vpc_cidr" { 
  type        = string 
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnets" { 
  type        = list(string) 
  description = "List of public subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" { 
  type        = list(string) 
  description = "List of private subnet CIDRs"
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "name_prefix" { 
  type        = string 
  description = "Naming prefix for all resources"
}

variable "common_tags" { 
  type        = map(string)
  description = "Base tags for all resources"
  default     = {
    ProjectCode = "Terraform101-CloudIntern"
  }
}