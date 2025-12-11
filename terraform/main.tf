########################################
# VPC + Subnets públicas
########################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "pokedex-vpc"
    Project = "PokeFinder"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "pokedex-igw"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "pokedex-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "pokedex-public-b"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "pokedex-public-rt"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

########################################
# Security Groups
########################################

# SG del Load Balancer (HTTP público)
resource "aws_security_group" "alb_sg" {
  name        = "pokedex-alb-sg"
  description = "Allow HTTP from Internet to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pokedex-alb-sg"
  }
}

# SG de las instancias backend
resource "aws_security_group" "ec2_sg" {
  name        = "pokedex-ec2-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Postgres solo se usa dentro de la instancia (localhost), no se abre puerto 5432 hacia fuera

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pokedex-ec2-sg"
  }
}

########################################
# Load Balancer + Target Group + Listener
########################################

resource "aws_lb" "alb" {
  name               = "pokedex-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = {
    Name = "pokedex-alb"
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "pokedex-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "pokedex-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

########################################
# AMI (Amazon Linux 2023)
########################################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

########################################
# User Data con Docker + Docker Compose
########################################

# docker-compose con backend + postgres
locals {
  docker_compose = <<-EOC
    version: "3.8"
    services:
      db:
        image: postgres:16
        environment:
          POSTGRES_DB: pokedx
          POSTGRES_USER: pokedx_user
          POSTGRES_PASSWORD: supersecret
        volumes:
          - db_data:/var/lib/postgresql/data

      backend:
        image: ${var.backend_image}
        depends_on:
          - db
        environment:
          # Ajusta esto según tu backend
          DATABASE_URL: postgresql://pokedx_user:supersecret@db:5432/pokedx
        ports:
          - "80:8000"

    volumes:
      db_data:
  EOC
}

# Script de arranque (user_data)
locals {
  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Instalar docker-compose (plugin simple usando curl)
    curl -L "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    mkdir -p /opt/pokedex
    cd /opt/pokedex

    cat > docker-compose.yml << 'EOF'
    ${local.docker_compose}
    EOF

    /usr/local/bin/docker-compose up -d
  EOT
}

########################################
# Launch Template + Auto Scaling Group
########################################

resource "aws_launch_template" "lt" {
  name_prefix   = "pokedex-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "pokedex-backend"
      Project = "PokeFinder"
      Role    = "backend"
    }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "pokedex-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  tag {
    key                 = "Name"
    value               = "pokedex-asg-instance"
    propagate_at_launch = true
  }
}
