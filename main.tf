terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# --- VPC ---
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "DevVPC" }
}

# --- Subnet ---
resource "aws_subnet" "dev_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "DevSubnet" }
}

# --- Security Group (SSH engedélyezve) ---
resource "aws_security_group" "dev_sg" {
  name   = "DevSSH"
  vpc_id = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Key Pair ---
resource "aws_key_pair" "dev_key" {
  key_name   = "DevTerraformKey"
  public_key = file("${path.module}/dev_key.pub")
}

# --- EC2 Instance (DEV) ---
resource "aws_instance" "dev_vm" {
  ami                         = "ami-03e876513b1441cbf"  # Ubuntu 22.04 EU North
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.dev_subnet.id
  vpc_security_group_ids      = [aws_security_group.dev_sg.id]
  key_name                    = aws_key_pair.dev_key.key_name
  associate_public_ip_address = true

  tags = { Name = "DevVM" }
}

output "dev_public_ip" {
  value = aws_instance.dev_vm.public_ip
}
