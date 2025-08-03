#DATA BLOCK

data "aws_iam_policy" "AmazonECSTaskExecutionRolePolicy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_ecr_repository" "repo" {
  name = "devops-project"
}

data "aws_ecr_image" "latest_image" {
  repository_name = data.aws_ecr_repository.repo.name
  image_tag       = "latest"
}

# RESOURCE AND MODULE BLOCKS

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.aws_iam_policy.AmazonECSTaskExecutionRolePolicy.arn
}

resource "aws_vpc" "vpc_devops_project" {
  cidr_block           = local.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    name = local.vpc_name
  }

}

module "subnet_deployment" {
  for_each = {
    public_subnet_1 = {
      vpc_key   = "vpc_devops_project"
      cidr      = "10.0.2.0/24"
      name      = "public_subnet_1"
      public_ip = true
      av-zone   = "us-east-2a"
    }

    public_subnet_2 = {
      vpc_key   = "vpc_devops_project"
      cidr      = "10.0.3.0/24"
      name      = "public_subnet_2"
      public_ip = true
      av-zone   = "us-east-2b"
    }
    private_subnet_1 = {
      vpc_key   = "vpc_devops_project"
      cidr      = "10.0.4.0/24"
      name      = "private_subnet_1"
      public_ip = false
      av-zone   = "us-east-2a"
    }

    private_subnet_2 = {
      vpc_key   = "vpc_devops_project"
      cidr      = "10.0.5.0/24"
      name      = "private_subnet_2"
      public_ip = false
      av-zone   = "us-east-2b"
    }
  }

  source            = "./modules/subnet-module"
  vpc_id            = aws_vpc.vpc_devops_project.id
  subnet_cidr_block = each.value.cidr
  subnet_name       = each.value.name
  az                = each.value.av-zone
  map_public_ip     = each.value.public_ip
}

resource "aws_internet_gateway" "igw-vpc" {
  vpc_id = aws_vpc.vpc_devops_project.id
  tags = {
    Name = local.igw_name
  }
}
resource "aws_eip" "eip_nat" {
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.eip_nat.id
  subnet_id     = module.subnet_deployment["public_subnet_1"].subnet_id

  tags = {
    Name = local.nat_name
  }
}

# PUBLIC SUBNET ROUTE
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc_devops_project.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-vpc.id
  }

  tags = {
    Name = local.public_rt
  }
}

# PRIVATE SUBNET ROUTE
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc_devops_project.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }

  tags = {
    Name = local.private_rt
  }
}

resource "aws_route_table_association" "public_subnet_1_assoc" {
  subnet_id      = module.subnet_deployment["public_subnet_1"].subnet_id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_subnet_2_assoc" {
  subnet_id      = module.subnet_deployment["public_subnet_2"].subnet_id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_subnet_1_assoc" {
  subnet_id      = module.subnet_deployment["private_subnet_1"].subnet_id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_subnet_2_assoc" {
  subnet_id      = module.subnet_deployment["private_subnet_2"].subnet_id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_security_group" "alb_sg" {
  name        = local.alb_sg
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.vpc_devops_project.id

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
}

resource "aws_security_group" "ecs_tasks" {
  name        = local.ecs_task_sg
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.vpc_devops_project.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-tasks-sg"
  }
}

resource "aws_lb_target_group" "backend_tg" {
  name        = local.tg_name
  port        = 9000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc_devops_project.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 2
  }
}

resource "aws_lb" "app_lb" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    module.subnet_deployment["public_subnet_1"].subnet_id,
    module.subnet_deployment["public_subnet_2"].subnet_id
  ]
  enable_deletion_protection = false
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

resource "aws_db_subnet_group" "private_subnets_group" {
  name = local.subnet_group
  subnet_ids = [
    module.subnet_deployment["private_subnet_1"].subnet_id,
    module.subnet_deployment["private_subnet_2"].subnet_id,
  ]
  tags = {
    Name = local.subnet_group
  }
}

resource "aws_security_group" "rds_sg" {
  name        = local.rds_sg
  description = "Allow MySQL access from ECS"
  vpc_id      = aws_vpc.vpc_devops_project.id

  ingress {
    description     = "Allow MySQL from ECS tasks"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MySQL RDS Security Group"
  }
}

resource "aws_db_instance" "mysql_rds" {
  identifier        = local.identifier
  allocated_storage = local.allocated_storage
  storage_type      = local.storage_type
  engine            = local.engine
  engine_version    = local.engine_version
  instance_class    = local.instance_class
  db_name           = local.db_name
  username          = local.username
  password          = local.password

  db_subnet_group_name   = aws_db_subnet_group.private_subnets_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  publicly_accessible = false
  multi_az            = false

  tags = {
    Name = "MySQL RDS Instance"
  }
}



resource "aws_ecs_cluster" "ecs-cluster" {
  name = local.ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/my-ecs-task"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "my-ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "app"
    image     = "${data.aws_ecr_repository.repo.repository_url}:${data.aws_ecr_image.latest_image.image_tag}"
    essential = true

    portMappings = [
      {
        containerPort = 9000
        hostPort      = 9000
        protocol      = "tcp"
      }
    ]
    environment = [
      { name = "DB_HOST", value = aws_db_instance.mysql_rds.address },
      { name = "DB_USER", value = local.username },
      { name = "DB_PASSWORD", value = local.password },
      { name = "DB_NAME", value = local.db_name }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
        awslogs-region        = "us-east-2"
        awslogs-stream-prefix = "ecs"
      }
    }
    }
  ])
}

resource "aws_ecs_service" "ecs-service" {
  name            = local.ecs_service_name
  cluster         = aws_ecs_cluster.ecs-cluster.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 2

  network_configuration {
    subnets          = [module.subnet_deployment["private_subnet_1"].subnet_id, module.subnet_deployment["private_subnet_2"].subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend_tg.arn
    container_name   = "app"
    container_port   = 9000
  }

  depends_on = [aws_lb_listener.http]
}
