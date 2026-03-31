terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"

        }
    }
}

provider "aws" {
  region = "us-west-1"
}   

resource "aws_vpc" "capstone_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "terraform-vpc"
  }
}

resource "aws_internet_gateway" "vpc_IGW"  {
  vpc_id = aws_vpc.capstone_vpc.id

  tags = {
    Name = "aws_IGW"
  }
}

resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.capstone_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-west-1c"

    tags = {
        Name = "capstone_subnet"
    }
}

resource "aws_route_table" "capstone_routetable" {
  vpc_id = aws_vpc.capstone_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_IGW.id
  }

  tags = {
    Name = "capstone_routetable"
  }
}

resource "aws_route_table_association" "route_table_assiciation" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.capstone_routetable.id
}

resource "aws_security_group" "capstone_sg" {
  vpc_id = aws_vpc.capstone_vpc.id

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
    Name = "capstone-sg"
  }
}

resource "aws_ecr_repository" "capstone_repo" {
  name = "my-webpage"
  force_delete = true
  
  tags = {
    name = "capstone_ecr"
  }
}

resource "aws_ecs_cluster" "capstone_cluster" {
  name = "capstone-cluster"

  tags = {
    Name = "capstone-cluster"
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "capstone-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "capstone_task" {
  family                   = "capstone-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "capstone-container"
    image     = "${aws_ecr_repository.capstone_repo.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])
}

resource "aws_ecs_service" "capstone_service" {
  name            = "capstone-service"
  cluster         = aws_ecs_cluster.capstone_cluster.id
  task_definition = aws_ecs_task_definition.capstone_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet.id]
    security_groups  = [aws_security_group.capstone_sg.id]
    assign_public_ip = true
  }
}