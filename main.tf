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

//AMI configuration
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
resource "aws_vpc" "wordpress-vpc" {
  cidr_block       = var.cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "wordpress-VPC"
    project = "wordpress"
    Environment = var.environment[0]
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
    Environment = var.environment[0]
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
    Environment = var.environment[0]
  }
}

//Private subnets in 2 availability zones
resource "aws_subnet" "subnet3" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 3)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wordpress-server-subnet1"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "subnet4" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 4)
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "wordpress-server-subnet2"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "subnet5" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 5)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wordpress-data-subnet1"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}

resource "aws_subnet" "subnet6" {
  vpc_id            = aws_vpc.wordpress-vpc.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, 6)
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "wordpress-data-subnet2"
    Type = "Private"
    project = "wordpress"
    Environment = var.environment[0]
  }
}
//Internet gateway 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.wordpress-vpc.id

  tags = {
    Name = "wordpress-igw"
    project = "wordpress"
    Environment = var.environment[0]
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

// add a second nat gateway for the other public subnet


resource "aws_route_table" "route1" {
  vpc_id = aws_vpc.wordpress-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public route"
    project = "wordpress"
    Environment = var.environment[0]
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
    Environment = var.environment[0]
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
//Securtity group configuration private 
resource "aws_security_group" "wordpress-server" {
  name        = "wordpress-server"
  description = "wordpress-server network traffic"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "SSH from  bastion security group"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion-sgp.id] 
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
    Name = "Wordpress Server Traffic"
    project = "wordpress"
  }
}


resource "aws_security_group" "wordpress-alb" {
  name        = "wordpress-alb"
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
    Name = "ALB Traffic"
    project = "wordpress"
  }
}
resource "aws_security_group" "bastion-sgp" {
  name        = "Bastion sgp"
  description = "Allow traffic from my IP address to private instance"
  vpc_id      = aws_vpc.wordpress-vpc.id

  ingress {
    description = "20 from my work station only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.workstation_ip]
  }


  tags = {
    Name = "Bastion Traffic"
    project = "wordpress"
  }
}


//Internet facing application load balancer

resource "aws_lb" "wordpress-alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.wordpress-alb.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]


  enable_deletion_protection = false

  tags = {
    Environment = var.environment[0]
  }
}

// create key pairs 
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
//launch templates
resource "aws_launch_template" "launchtemplate1" {
  name = "wordpress-template"

  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.wordpress_key.key_name
  vpc_security_group_ids = [aws_security_group.wordpress-server.id]

  tag_specifications {
    resource_type = "instance"

    tags = {   
      Name = "Wordpress-server"
      project = "wordpress"
      environment = var.environment[0]
    }
  }

  user_data = filebase64("install_wordpress.sh")
}

resource "aws_instance" "bastion" {
  ami          = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  associate_public_ip_address = "true"
  availability_zone = var.availability_zones[0]
  subnet_id = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.bastion-sgp.id]
  key_name = aws_key_pair.wordpress_key.key_name
 
 tags = {
    Name = "wp-bastion-instance"
  }
}

// ALB target,  Listener
resource "aws_alb_target_group" "wordpress-server" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.wordpress-vpc.id
}

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_lb.wordpress-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.wordpress-server.arn
  }
}

resource "aws_alb_listener_rule" "alb-rule1" {
  listener_arn = aws_alb_listener.front_end.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.wordpress-server.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

// Auto Scaling group 

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = [aws_subnet.subnet3.id, aws_subnet.subnet4.id]

  desired_capacity = 2
  max_size         = 2
  min_size         = 2

  target_group_arns = [aws_alb_target_group.wordpress-server.arn]

  launch_template {
    id      = aws_launch_template.launchtemplate1.id
    version = "$Latest"
  }
}
//Aurora db credentials.  
/*data "aws_secretsmanager_secret_version" "creds" {
  name = "db credentials"
  secret_id = "wordpress-db-credentials"
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
} */

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "wordpress-db-credentials"
}


locals {
  db_creds = jsondecode(
    data.aws_secretsmanager_secret_version.creds.secret_string
  )
}

// Add Aurora cluster config
resource "aws_rds_cluster" "wordpress-aurora-cluster" {
  cluster_identifier      = "aurora-cluster-wordpress"
  engine                  = "aurora-mysql"
  availability_zones      = var.availability_zones
  database_name           = "wordpressdb"
  master_username         = local.db_creds.username
  master_password         = local.db_creds.password
  backup_retention_period = 0
  //preferred_backup_window = "02:00-04:00"
  skip_final_snapshot = true
  apply_immediately = true
}

