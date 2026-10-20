Dulay-Capstone: AWS 3-Tier Architecture with Terraform

Architecture Diagram

Project Overview

This repository contains the Terraform infrastructure code for a highly available, secure 3-tier AWS architecture. Developed as a final capstone project for the Cloud Engineering Internship, this project adheres to Infrastructure as Code (IaC) best practices, utilizing a modular design to provision networking, compute, and load balancing resources across two Availability Zones (AZ-A and AZ-B).

The infrastructure is designed with strict perimeter security, enforcing least privilege access through carefully mapped Security Groups, and maintains a remote backend in Amazon S3 for state management to facilitate secure operations.

Repository Structure

├── bootstrap/            # Initial setup files 
├── modules/              # Reusable Terraform child modules
│   ├── compute/          # EC2 instances, ASGs, and Target Groups
│   ├── load_balancer/    # Application (ALB) and Network (NLB) Load Balancers
│   ├── security_groups/  # Dynamic SG generation mapping ingress/egress rules
│   └── vpc/              # VPC, Subnets, NAT/Internet Gateways, Route Tables
├── scripts/              # Initialization and user-data scripts for instances
├── tests/                # Load and stress testing scripts (k6)
├── .gitignore            # Git ignore configurations
├── 01_main.tf            # Root module defining global variables and calling child modules
├── 02_variables.tf       # Root variable definitions (identity, region, networking)
├── 03_outputs.tf         # Exposed infrastructure outputs (IPs, DNS names)
├── backend.tf            # Remote S3 state and locking configuration
├── README.md             # Project documentation
└── terraform.tfvars      # Environment-specific variable assignments


Security & Networking

The network traffic is heavily regulated to prevent direct internet access to instances and to secure the administrative paths:

Bastion Host: Accessible only via SSH from the designated vpn_ip.

Application Load Balancer (ALB): The only public-facing entry point (HTTP/80) to the application.

Frontend ASG: Only accepts HTTP traffic that has passed through the ALB, and SSH traffic from the Bastion.

Backend ASG: Isolated in private subnets. Only accepts HTTP traffic from the VPC CIDR (for internal NLB routing and health checks) and SSH traffic from the Bastion.

Mandatory Tagging Standards

All resources deployed through this configuration are automatically tagged using local variables. The module automatically merges base tags with dynamically generated tags:

Name: {Lastname}-FinalProject-{ResourceType}

Engineer: {Lastname}-{Firstname}

ProjectCode: Terraform101-CloudIntern

Getting Started

Prerequisites

Terraform v1.14.3 or higher.

AWS CLI configured with appropriate credentials.

An existing S3 bucket (dulay-finalproject-terraform-state) initialized for remote state with versioning enabled.

Configuration Setup

Before initializing Terraform, create or update your terraform.tfvars file in the root directory. You must replace the placeholder VPN IP with your actual IP address to ensure secure SSH access to the Bastion Host.

Security Note: Never commit your actual VPN IP to version control.

region = "ap-southeast-1"
vpn_ip = "YOUR_VPN_IP/32" # Replace with your actual IP address

common_tags = {
  "ProjectCode" = "Terraform101-CloudIntern"
}


Deployment Steps

Initialize Terraform: Downloads providers and configures the S3 backend.

terraform init


Plan Infrastructure: Review the execution plan to verify resource creation and tagging.

terraform plan


Apply Configuration: Provision the resources in your AWS account.

terraform apply


Outputs

Upon a successful terraform apply, the terminal will output the following essential connectivity details:

bastion_public_ip: Your SSH entry point into the VPC.

bastion_private_ip: Internal IP of the Bastion Host for internal network verification.

frontend_alb_dns: The public URL to access the frontend application (primary target for testing).

backend_nlb_dns: The internal DNS used for backend verification.

frontend_ips: Actual Private IPs of Frontend ASG Instances.

backend_ips: Actual Private IPs of Backend ASG Instances.

Stress Testing

This repository includes a k6 stress testing script to validate the Application Load Balancer and Auto Scaling Group policies.

To run the test against the provisioned infrastructure, use the target URL exported by Terraform:

k6 run -e TARGET_URL=http://$(terraform output -raw frontend_alb_dns) tests/stress_test.js


The script will jump to 300 virtual users and hold for 3 minutes to verify that CloudWatch alarms trigger and scale the environment accordingly.
