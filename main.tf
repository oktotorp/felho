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

#######################
# KEY PAIR (használt kulcs)
#######################
resource "aws_key_pair" "dev_key" {
  key_name   = "DevTerraformKey"
  public_key = file("${path.module}/ubuntu_key.pub")
}

resource "aws_key_pair" "test_key" {
  key_name   = "TestTerraformKey"
  public_key = file("${path.module}/ubuntu_key.pub")
}

resource "aws_key_pair" "prod_key" {
  key_name   = "ProdTerraformKey"
  public_key = file("${path.module}/ubuntu_key.pub")
}

#######################
# DEV VPC és EC2
#######################
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "DevVPC" }
}

resource "aws_subnet" "dev_subnet" {
  vpc_id            = aws_vpc.dev_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "DevSubnet" }
}

resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id
}

resource "aws_route_table" "dev_rt" {
  vpc_id = aws_vpc.dev_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }
}

resource "aws_route_table_association" "dev_rta" {
  subnet_id      = aws_subnet.dev_subnet.id
  route_table_id = aws_route_table.dev_rt.id
}

resource "aws_security_group" "dev_sg" {
  name        = "DevSSH"
  description = "Allow SSH from anywhere"
  vpc_id      = aws_vpc.dev_vpc.id

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

resource "aws_instance" "dev_vm" {
  ami                         = "ami-03e876513b1441cbf"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.dev_subnet.id
  key_name                    = aws_key_pair.dev_key.key_name
  vpc_security_group_ids      = [aws_security_group.dev_sg.id]
  associate_public_ip_address = true

  tags = { Name = "DevVM" }
}

output "dev_public_ip" {
  value = aws_instance.dev_vm.public_ip
}

#######################
# TEST VPC és EC2 (SSH kikapcsolva)
#######################
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.1.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "TestVPC" }
}

resource "aws_subnet" "test_subnet" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "TestSubnet" }
}

resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id
}

resource "aws_route_table" "test_rt" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test_igw.id
  }
}

resource "aws_route_table_association" "test_rta" {
  subnet_id      = aws_subnet.test_subnet.id
  route_table_id = aws_route_table.test_rt.id
}

resource "aws_security_group" "test_sg" {
  name        = "TestNoSSH"
  description = "No SSH access allowed"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_instance" "test_vm" {
  ami                         = "ami-03e876513b1441cbf"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.test_subnet.id
  key_name                    = aws_key_pair.test_key.key_name
  vpc_security_group_ids      = [aws_security_group.test_sg.id]
  associate_public_ip_address = true

  tags = { Name = "TestVM" }
}

output "test_public_ip" {
  value = aws_instance.test_vm.public_ip
}

#######################
# PROD VPC és Autoscaling
#######################
resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.2.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = { Name = "ProdVPC" }
}

resource "aws_subnet" "prod_subnet" {
  vpc_id            = aws_vpc.prod_vpc.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = "eu-north-1a"
  map_public_ip_on_launch = true
  tags = { Name = "ProdSubnet" }
}

resource "aws_internet_gateway" "prod_igw" {
  vpc_id = aws_vpc.prod_vpc.id
}

resource "aws_route_table" "prod_rt" {
  vpc_id = aws_vpc.prod_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_igw.id
  }
}

resource "aws_route_table_association" "prod_rta" {
  subnet_id      = aws_subnet.prod_subnet.id
  route_table_id = aws_route_table.prod_rt.id
}

resource "aws_security_group" "prod_sg" {
  name        = "ProdSG"
  description = "Allow HTTP/HTTPS only"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_launch_template" "prod_lt" {
  name_prefix   = "prod-lt-"
  image_id      = "ami-03e876513b1441cbf"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.prod_key.key_name
  security_group_names = [aws_security_group.prod_sg.name]

  user_data = base64encode(<<EOF
#!/bin/bash
sudo apt update -y
sudo apt install -y apache2
sudo systemctl enable apache2
sudo systemctl start apache2
echo "Prod environment web page" | sudo tee /var/www/html/index.html
EOF
  )
}

resource "aws_autoscaling_group" "prod_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.prod_subnet.id]
  launch_template {
    id      = aws_launch_template.prod_lt.id
    version = "$Latest"
  }
  health_check_type = "EC2"
}

output "prod_asg_name" {
  value = aws_autoscaling_group.prod_asg.id
}

output "prod_launch_template_id" {
  value = aws_launch_template.prod_lt.id
}
