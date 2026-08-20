#root module defines global variables, naming + tags, calls child modules, expose outputs

#creates standardized naming and tagging
locals {
  name_prefix = "${var.lastname}-FinalProject"
  effective_tags = merge(var.common_tags, {
    Engineer = "${var.lastname}-${var.firstname}"
  })
} #all resources get consistent names + tags, adds engineer tag automatically

provider "aws" {
  region = var.region
}

# --- VPC ---
module "vpc" {
  source      = "./modules/vpc"
  name_prefix = local.name_prefix
  common_tags = local.effective_tags
}

# --- SECURITY GROUPS ---
# instead of writing a separate resource for every group and rule, use configuration map to tell the module what to build (DRY, scalable)
module "security_groups" {
  source      = "./modules/security_groups"
  vpc_id      = module.vpc.vpc_id
  name_prefix = local.name_prefix
  common_tags = local.effective_tags

  sg_configs = { #keys -> "Bastion-SG" etc are the unique names for the groups, module uses these keys to name the resources in AWS
    "BASTION-SG" = {
      description = "SSH only from VPN IP"
      ingress_rules = [{
        from_port                = 22 #service port being opened
        to_port                  = 22
        protocol                 = "tcp"        #communication method
        cidr_blocks              = [var.vpn_ip] # Perimeter Security: Only allows the admin's specific VPN IP.
        source_security_group_id = null         #group based access disabled
      }]
    },
    "ALB-SG" = {
      description = "HTTP from internet"
      ingress_rules = [{
        from_port                = 80
        to_port                  = 80
        protocol                 = "tcp"
        cidr_blocks              = ["0.0.0.0/0"] #opens port 80 to the entire internet -> resources in the public subnet are open to all
        source_security_group_id = null
      }]
    },
    "FRONTEND-SG" = {
      description = "only from ALB + Bastion"
      ingress_rules = [
        {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = null
          # Secure Path: Only allows traffic that passed through the ALB-SG.
          # This prevents users from bypassing the Load Balancer to hit instances directly.
          source_security_group_id = "ALB-SG"
        },
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = null
          # Admin Path: Only allows SSH management traffic from the BASTION-SG.
          source_security_group_id = "BASTION-SG"
        }
      ]
    },
    "BACKEND-SG" = {
      description = "only from VPC CIDR + Bastion"
      ingress_rules = [
        { #ensures the internal NLB and Frontend Instances can communicate with the backend layer while maintaining the bastion-rule only for
          from_port = 80
          to_port   = 80
          protocol  = "tcp"
          # NLB Requirement: Uses the VPC CIDR to allow internal Frontend instances 
          # and the Network Load Balancer (NLB) to perform health checks.
          cidr_blocks              = ["10.0.0.0/16"]
          source_security_group_id = null
        },
        {
          from_port   = 22
          to_port     = 22
          protocol    = "tcp"
          cidr_blocks = null
          # Consistent Admin Path: Only allows SSH from the Bastion Host.
          source_security_group_id = "BASTION-SG"
        }
      ]
    }
  }
} #enforces: least privilege, no direct internet to instances, LB-only access path

# --- LOAD BALANCER ---
module "load_balancer" {
  source             = "./modules/load_balancer"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  alb_sg_id          = module.security_groups.sg_ids["ALB-SG"]
  name_prefix        = local.name_prefix
  common_tags        = local.effective_tags
}

# --- COMPUTE ---
module "compute" {
  source             = "./modules/compute"
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_ids[0]
  private_subnet_ids = module.vpc.private_subnet_ids
  bastion_sg_id      = module.security_groups.sg_ids["BASTION-SG"]
  frontend_sg_id     = module.security_groups.sg_ids["FRONTEND-SG"]
  backend_sg_id      = module.security_groups.sg_ids["BACKEND-SG"]
  frontend_tg_arn    = module.load_balancer.frontend_tg_arn
  backend_tg_arn     = module.load_balancer.backend_tg_arn
  backend_lb_dns     = module.load_balancer.backend_lb_dns
  name_prefix        = local.name_prefix
  common_tags        = local.effective_tags
} #attaches SGs to instances, registers ASGs to target groups, configures backend connectivity