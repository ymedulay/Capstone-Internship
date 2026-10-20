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

```

## Security & Networking
The network traffic is heavily regulated to prevent direct internet access to instances and to secure the administrative paths:

- Bastion Host: Accessible only via SSH from the designated vpn_ip.
- Application Load Balancer (ALB): The only public-facing entry point (HTTP/80) to the application.
- Frontend ASG: Only accepts HTTP traffic that has passed through the ALB, and SSH traffic from the Bastion.
- Backend ASG: Isolated in private subnets. Only accepts HTTP traffic from the VPC CIDR (for internal NLB routing and health checks) and SSH traffic from the Bastion.


## Mandatory Tagging Standards
All resources deployed through this configuration are automatically tagged using local variables. The module automatically merges base tags with dynamically generated tags:

Name: {Lastname}-FinalProject-{ResourceType}
Engineer: {Lastname}-{Firstname}
ProjectCode: Terraform101-CloudIntern

## Getting Started
Prerequisites
- Terraform v1.14.3 or higher.
- AWS CLI configured with appropriate credentials.
- An existing S3 bucket (example-terraform-state) initialized for remote state with versioning enabled.

## Configuration Setup
Before initializing Terraform, create or update your terraform.tfvars file in the root directory. You must replace the placeholder VPN IP with your actual IP address to ensure secure SSH access to the Bastion Host.

**Security Note: Never commit your actual VPN IP to version control.**
```text
region = "ap-southeast-1"
vpn_ip = "YOUR_VPN_IP/32" # Replace with your actual IP address

common_tags = {
  "ProjectCode" = "Terraform101-CloudIntern"
}
```

## Deployment Steps

```text
1.  **Bootstrap the Remote Backend:**
    Before deploying the main infrastructure, you must create the S3 bucket for remote state storage. Navigate to the bootstrap directory and apply the initial configuration:
    ```bash
    cd bootstrap
    terraform init
    terraform apply
    cd ..
    ```

2.  **Initialize Main Infrastructure:**
    From the root directory, initialize Terraform to download providers and configure the S3 backend using the bucket you just created.
    ```bash
    terraform init
    ```

3.  **Plan Infrastructure:**
    Review the execution plan to verify resource creation, modular connections, and tagging.
    ```bash
    terraform plan
    ```

4.  **Apply Configuration:**
    Provision the AWS resources for the 3-tier architecture.
    ```bash
    terraform apply
    ```
```
