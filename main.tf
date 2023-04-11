provider "aws" {
  region = "eu-west-3"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}


resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
 
  tags = {
    Name = "igw"
  }
}
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
}

/* Routing table for public subnet */
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name   = "public-route-table"
    }
}

/* Route table associations */
resource "aws_route_table_association" "public" {
 
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
  
}
resource "aws_security_group" "web_sg" {
  name = "web-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["91.231.246.50/32"]
  }
  egress {
    from_port        = "0"
    to_port          = "0"
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_instance" "web" {
  ami           = "ami-069fa606c9a99d947"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id

 

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl enable httpd
              systemctl start httpd
              EOF

  tags = {
    Name = "web"
  }
}


resource "aws_eip" "web_eip" {
  instance = aws_instance.web.id
  
  vpc      = true
}

resource "aws_lb" "web_lb" {
  name               = "web-lb"
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_subnet.id]

}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

resource "aws_lb_target_group" "web_target_group" {
  name        = "web-tg"
  port        = 80
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    path                = "/"
  }

}

resource "aws_lb_target_group_attachment" "web_tga" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id        = aws_instance.web.id
}

resource "aws_security_group_rule" "web_lb_ingress" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["91.231.246.50/32"]
  security_group_id = aws_security_group.web_sg.id
}