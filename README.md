# Dulay-Capstone: AWS 3-Tier Architecture with Terraform

## Architecture Diagram
![AWS 3-Tier Architecture](image_c5c8aa.png)

## Project Overview
This repository contains the Terraform infrastructure code for a highly available, secure 3-tier AWS architecture. Developed as a final capstone project for the Cloud Engineering Internship, this project adheres to Infrastructure as Code (IaC) best practices, utilizing a modular design to provision networking, compute, and load balancing resources across two Availability Zones (AZ-A and AZ-B).

The infrastructure is designed with strict perimeter security, enforcing least privilege access through carefully mapped Security Groups, and maintains a remote backend in Amazon S3 for state management to facilitate secure operations.

## Repository Structure
```text
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

## Security & Networking
The network traffic is heavily regulated to prevent direct internet access to instances and to secure the administrative paths:

Bastion Host: Accessible only via SSH from the designated vpn_ip.
Application Load Balancer (ALB): The only public-facing entry point (HTTP/80) to the application.
Frontend ASG: Only accepts HTTP traffic that has passed through the ALB, and SSH traffic from the Bastion.
Backend ASG: Isolated in private subnets. Only accepts HTTP traffic from the VPC CIDR (for internal NLB routing and health checks) and SSH traffic from the Bastion.
