terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.22.0"
    }
  }
}

provider "aws" {
    profile = "mel@wordpressprj"
    region = "eu-south-1"
    
}

resource "aws_vpc" "wordpress-vpc" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "wordpress-VPC"
    project = "wordpress"
    environment = var.environment[0]
  }
}

//Public subnet in two availability zones
resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wordpress-subnet-pub1"
    Type = "Public"
    project = "wordpress"
    environment = var.environment[0]
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 2)
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "wordpress-subnet-pub2"
    Type = "Public"
    project = "wordpress"
    environment = var.environment[0]
  }
}

//Private subnets in 2 availability zones
resource "aws_subnet" "subnet3" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 3)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wordpress-subnet-pri1"
    Type = "Private"
    project = "wordpress"
    environment = var.environment[0]
  }
}

resource "aws_subnet" "subnet4" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 4)
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "wordpress-subnet-pri2"
    Type = "Private"
    project = "wordpress"
    environment = var.environment[0]
  }
}

//Internet gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "wordpress-igw"
    project = "wordpress"
    environment = var.environment[0]
  }
}

//Elastic ip address for the nat gateway
resource "aws_eip" "nat-eip" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "wordpress-NAT"

  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "route1" {
  vpc_id = aws_vpc.wordpress-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public route"
    project = "wordpress"
    environment = var.environment[0]
  }
}

resource "aws_route_table" "route2" {
  vpc_id = aws_vpc.wordpress-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "Private route"
    project = "wordpress"
    environment = var.environment[0]
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route1.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.route1.id
}

resource "aws_route_table_association" "rta3" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.route2.id
}

resource "aws_route_table_association" "rta4" {
  subnet_id      = aws_subnet.subnet4.id
  route_table_id = aws_route_table.route2.id
}
//Securtity group configuration
resource "aws_security_group" "wordpress-server" {
  name        = "wordpress-server"
  description = "wordpress-server network traffic"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.workstation_ip]
  }

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [
      cidrsubnet(var.cidr_block, 8, 1),
      cidrsubnet(var.cidr_block, 8, 2)
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow Traffic"
  }
}

resource "aws_security_group" "alb" {
  name        = "alb"
  description = "alb network traffic"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "80 from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.wordpress-server.id]
  }

  tags = {
    Name = "Allow  Traffic"
    project = "wordpress"
  }
}


/*
//launch templates
resource "aws_launch_template" "launchtemplate1" {
  name = "web"

  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.wordpress-server.id]

  tag_specifications {
    resource_type = "instance"

    tags = {   
      Name = "Wordpress-server"
      project = "wordpress"
      environment = var.environment[0]
    }
  }

  user_data = filebase64("${path.module}/ec2.userdata")
}*/

