#Create a network with public and private subnets

provider "aws" {
  region = "us-east-1"  # Change region as per required
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet2"
  }
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id    = aws_vpc.my_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "PrivateSubnet1"
  }
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id    = aws_vpc.my_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "PrivateSubnet2"
  }
}

----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
#Provision an ECS cluster and load balancer
Add an ECS service that serves the base nginx image
Set the default route for the ALB that serves the default route of the nginx image


provider "aws" {
  region = "us-east-1"  # Change this to your desired region
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "private_subnet" {
  count = 2

  cidr_block = "10.0.${count.index + 1}.0/24"
}

resource "aws_lb" "my_lb" {
  name               = "my-ecs-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = []  # Add your security groups here

  enable_deletion_protection = false

  enable_http2        = true
  idle_timeout        = 60
  enable_cross_zone_load_balancing = true

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "my-ecs-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path     = "/"
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_listener" "my_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    type             = "forward"
  }
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "my-ecs-cluster"
}

resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "my-container",
      image = "nginx:latest",
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 0,
        },
      ],
    },
  ])
}

resource "aws_ecs_service" "my_ecs_service" {
  name            = "my-ecs-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.my_task_definition.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets = aws_subnet.private_subnet[*].id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    container_name   = "my-container"
    container_port   = 80
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
        },
      },
    ],
  })
}

----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
#Create an S3 bucket and configure the Terraform to allow the nginx task to write to the S3 bucket


provider "aws" {
  region = "us-east-1"  # Change this to your desired region
}

resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "my-nginx-s3-bucket"
  acl    = "private"  # Adjust the ACL as needed

  versioning {
    enabled = true
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com",
        },
      },
    ],
  })
}

resource "aws_iam_policy" "s3_write_policy" {
  name        = "s3_write_policy"
  description = "Allows writing to the S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
        ],
        Effect   = "Allow",
        Resource = aws_s3_bucket.my_s3_bucket.arn,
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "s3_write_attachment" {
  policy_arn = aws_iam_policy.s3_write_policy.arn
  role       = aws_iam_role.ecs_execution_role.name
}

resource "aws_ecs_task_definition" "my_task_definition" {
  family                   = "my-ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "my-container",
      image = "nginx:latest",
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 0,
        },
      ],
      environment = [
        {
          name  = "AWS_ACCESS_KEY_ID",
          value = aws_iam_role.ecs_execution_role.name
        },
        {
          name  = "AWS_SECRET_ACCESS_KEY",
          value = aws_iam_role.ecs_execution_role.arn
        },
        {
          name  = "S3_BUCKET_NAME",
          value = aws_s3_bucket.my_s3_bucket.bucket
        },
      ],
    },
  ])
}
