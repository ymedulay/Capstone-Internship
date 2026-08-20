#vpc module creates -> 1 vpc, 2 pub subnets, 2 priv subnets, 1 IGW, 1 NAT, route tables

#data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# --- VPC ---
#req 1: creates the vpc w/ the specific cidr block
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-VPC"
  })
}

# --- INTERNET GATEWAY ---
#req 1: attaches 1 IGW to allow public internet access for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-IGW"
  })
}

# --- SUBNETS ---
#req 1: creates 2 public subnets using the CIDRs
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets) #count-loop -> creates a subnet for every item in the public_subnets list
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index] #list indexing -> selects the CIDR for this iteration
  availability_zone       = data.aws_availability_zones.available.names[count.index] #data source indexing -> assigns an AZ to ensure high availability
  map_public_ip_on_launch = true #public subnets auto assign IPs
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-Public-AZ${count.index + 1}" #dynamic naming -> automatically names them PublicAZ1 and AZ2
  })
}

resource "aws_subnet" "private" { #repeats same logic
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-Private-AZ${count.index + 1}"
  })
}

# --- EIP ---
resource "aws_eip" "nat_eip" {
  domain = "vpc" #allocates a static IP for the NAT Gateway
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-NAT-EIP"
  })
}

# --- NAT ---
resource "aws_nat_gateway" "nat" {
  #provisions a NAT gateway to allow private instances outbound access
  allocation_id = aws_eip.nat_eip.id
  #list indexing -> specifically places the NAT in the 2nd public subnet as requested
  subnet_id     = aws_subnet.public[1].id 
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-NAT-AZ2"
  })
  depends_on = [aws_internet_gateway.igw] #ensures that the NAT is only deployed when the IGW is complete
}

# --- ROUTING TABLE ---
#defines routing rules for public subnets to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-PublicRT"
  })
}

#defines routing rules for private subnets to NAT gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-PrivateRT"
  })
}

resource "aws_route_table_association" "public" {
  #count loop -> loops through pub subs to associate them with the public route table
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}