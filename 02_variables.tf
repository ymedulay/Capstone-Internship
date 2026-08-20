#root variable only passes values, while the modules defines what input it needs
#reusable, self-contained, and easier to maintain

# --- Identity & Global Variables ---

variable "lastname" {
  description = "User's last name, used for dynamic resource naming and identification"
  type        = string
}

variable "firstname" {
  description = "User's first name, primarily used for tagging 'Engineer' metadata"
  type        = string
}

variable "region" {
  description = "The AWS Region where all resources will be deployed"
  type        = string
}

variable "common_tags" {
  description = "A map of mandatory base tags applied to all resources"
  type        = map(string)
}

# --- Security & Environment Specifics ---

variable "vpn_ip" {
  description = "The specific public IP allowed to access the Bastion host via SSH"
  type        = string
}