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

//Create VPC
resource "aws_vpc" "wordpress-vpc" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "Wordpress-project-VPC"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

// create two public subnets in two availability zones 

//Public subnet in two availability zones
resource "aws_subnet" "public-subnet1" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 1)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "Public-Subnet-1a-wordpress "
    Type = "Public"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "public-subnet2" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 2)
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "Public-Subnet-1b-wordpress"
    Type = "Public"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

// create 4 private subnets (server + data * 2) in two availability zones 

resource "aws_subnet" "private-subnet1" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 3)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "Private-Server-Subnet-1a-wordpress"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "private-subnet2" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 4)
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "Private-Server-Subnet-1b-wordpress"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "private-subnet3" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 5)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "Private-data-Subnet-1a-wordpress"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "private-subnet4" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 6)
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "Private-data-Subnet-1b-wordpress"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

// create bastion host server in the public subnet with Launch template

//create internet gateway to attach to public subnet
resource "aws_internet_gateway" "igw-wordpress" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "wordpress-internet-gateway"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

// create route table and associate to public subnet 
resource "aws_route_table" "route1" {
  vpc_id = aws_vpc.wordpress-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-wordpress.id
  }

  tags = {
    Name = "Internet Public Route - Wordpress"
    project = "wordpress"
    Environment = var.environment[0]
  }
}
// associate route table1 (igw) to 2 public subnets .  

resource "aws_route_table_association" "public-rta1" {
  subnet_id      = aws_subnet.public-subnet1.id
  route_table_id = aws_route_table.route1.id
}

resource "aws_route_table_association" "public-rta2" {
  subnet_id      = aws_subnet.public-subnet2.id
  route_table_id = aws_route_table.route1.id
}

/*create bastion host launch template to access server in private subnet 
AMI configuration for launch templates
Create bastion security group*/
resource "aws_security_group" "bastion-sg" {
  name        = "Bastion Security Group"
  description = "Allow SSH only from my work station"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "SSH to bastion security group"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.workstation_ip]
    
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Bastion Traffic"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Canonical
  owners = ["099720109477"]
}
// Create key pair for instances
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "wordpress_key" {
  key_name   = "wordpress-project-key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "local_file" "key-file" {
    content  = tls_private_key.rsa.private_key_pem
    filename = aws_key_pair.wordpress_key.key_name
}

// Bastion Launch Template
resource "aws_launch_template" "bastion-template" {
  name = "bastion-wordpress-template"

  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wordpress_key.key_name
  

network_interfaces {
  security_groups = [aws_security_group.bastion-sg.id]
  associate_public_ip_address = true
  delete_on_termination       = true 
}

  tag_specifications {
    resource_type = "instance"

    tags = {   
      Name = "Bastion public instance"
      project = "wordpress"
      environment = var.environment[0]
    }
  }
}

// Bastion Auto Scaling group for multi AZ 
resource "aws_autoscaling_group" "bastion-asg" {
  vpc_zone_identifier = [aws_subnet.public-subnet1.id, aws_subnet.public-subnet2.id]
  //availability_zones = var.availability_zones
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1

  
  launch_template {
    id      = aws_launch_template.bastion-template.id
    version = "$Latest"
  }
  
}

// web server configuration: ASG, Launch Template, Security Group

resource "aws_autoscaling_group" "server-asg" {
  vpc_zone_identifier = [aws_subnet.private-subnet1.id, aws_subnet.private-subnet2.id]
  //availability_zones = var.availability_zones
  desired_capacity   = 1
  max_size           = 1
  min_size           = 1

  launch_template {
    id      = aws_launch_template.server-template.id
    version = "$Latest"
  }
} 
  
  resource "aws_launch_template" "server-template" {
  name = "private-wordpress-template"

  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wordpress_key.key_name
  vpc_security_group_ids = [aws_security_group.wordpress-server-sg.id]

  tag_specifications {
    resource_type = "instance"
  
    tags = {   
      Name = "Private wp-Server Instance"
      project = "wordpress"
      environment = var.environment[0]
    }
  }
}


resource "aws_security_group" "wordpress-server-sg" {
  name        = "private-wordpress-server-sg"
  description = "wordpress-server network traffic"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "SSH from  bastion security group"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-sg.id] 
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
    Name = "Wordpress Private Server sg"
    project = "wordpress"
  }
}

//Create credentials for my aurora db
resource "random_password" "password" {
  length           = 20
  special          = true
  override_special = "_%@"
}

resource "aws_secretsmanager_secret" "aurora-masterDB" {
   name = "aurora-secret"
}

resource "aws_secretsmanager_secret_version" "sversion" {
  secret_id = aws_secretsmanager_secret.aurora-masterDB.id
  secret_string = <<EOF
   {
    "username": "adminaccount",
    "password": "${random_password.password.result}"
   }
EOF
}

data "aws_secretsmanager_secret" "aurora-masterDB" {
  arn = aws_secretsmanager_secret.aurora-masterDB.arn
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = data.aws_secretsmanager_secret.aurora-masterDB.arn
}


locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}


//Create aurora db for wordpress data 
resource "aws_rds_cluster" "wordpress-aurora-cluster" {
  cluster_identifier      = "aurora-cluster-wordpress"
  engine                  = "aurora-mysql"
  availability_zones      = var.availability_zones
  database_name           = "wordpressdb"
  master_username         = local.db_creds.username
  master_password         = local.db_creds.password
  backup_retention_period = 0
  vpc_security_group_ids = [aws_security_group.aurora-sgp.id]
  skip_final_snapshot = true
  apply_immediately = true
  //preferred_backup_window = "02:00-04:00"
  //engine_mode = "serverless"

//Milan does not support serverless feature of aurora
  /*scaling_configuration {
    max_capacity = 1.0
    min_capacity = 2.0
  }*/
}

// aurora security group.  

resource "aws_security_group" "aurora-sgp" {
  name = "Wordpress Aurora Access"
  description = "Aurora security group"
  ingress {
    description = "VPC bound acces"
    from_port = 3306
    to_port = 3306
    protocol    = "tcp"
    cidr_blocks = [
      cidrsubnet(var.cidr_block, 8, 3),
      cidrsubnet(var.cidr_block, 8, 4), var.workstation_ip
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}