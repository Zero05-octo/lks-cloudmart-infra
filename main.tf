# CloudMart Infrastructure - Terraform
resource "aws_vpc" "lks_mart_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "lks-mart-vpc" }
}

resource "aws_internet_gateway" "lks_igw" {
  vpc_id = aws_vpc.lks_mart_vpc.id
  tags   = { Name = "lks-mart-igw" }
}

resource "aws_subnet" "pub_sub_a" {
  vpc_id                  = aws_vpc.lks_mart_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "lks-mart-pub-sub-a" }
}

resource "aws_subnet" "pub_sub_b" {
  vpc_id                  = aws_vpc.lks_mart_vpc.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "lks-mart-pub-sub-b" }
}

resource "aws_subnet" "priv_sub_a" {
  vpc_id            = aws_vpc.lks_mart_vpc.id
  cidr_block        = "10.20.11.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "lks-mart-priv-sub-a" }
}

resource "aws_subnet" "priv_sub_b" {
  vpc_id            = aws_vpc.lks_mart_vpc.id
  cidr_block        = "10.20.12.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "lks-mart-priv-sub-b" }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags   = { Name = "lks-mart-nat-eip" }

}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_sub_a.id
  tags          = { Name = "lks-mart-nat-gw" }
  depends_on    = [aws_internet_gateway.lks_igw]
}

resource "aws_route_table" "pub_rtb" {
  vpc_id = aws_vpc.lks_mart_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lks_igw.id
  }
  tags = { Name = "lks-mart-pub-rtb" }

}

resource "aws_route_table" "priv_rtb" {
  vpc_id = aws_vpc.lks_mart_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "lks-mart-priv-rtb" }

}

resource "aws_route_table_association" "pub_rtb_ass_a" {
  subnet_id      = aws_subnet.pub_sub_a.id
  route_table_id = aws_route_table.pub_rtb.id
}

resource "aws_route_table_association" "pub_rtb_ass_b" {
  subnet_id      = aws_subnet.pub_sub_b.id
  route_table_id = aws_route_table.pub_rtb.id
}

resource "aws_route_table_association" "priv_rtb_ass_a" {
  subnet_id      = aws_subnet.priv_sub_a.id
  route_table_id = aws_route_table.priv_rtb.id
}

resource "aws_route_table_association" "priv_rtb_ass_b" {
  subnet_id      = aws_subnet.priv_sub_b.id
  route_table_id = aws_route_table.priv_rtb.id
}

resource "aws_security_group" "alb_sg" {
  name        = "lks-mart-alb-sg"
  description = "SG for ALB"
  vpc_id      = aws_vpc.lks_mart_vpc.id

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
  tags = { Name = "lks-mart-alb-sg" }
}

resource "aws_security_group" "ecs_sg" {
  name        = "lks-mart-ecs-sg"
  description = "SG for ECS"
  vpc_id      = aws_vpc.lks_mart_vpc.id

  dynamic "ingress" {
    for_each = [80, 3000, 3001, 3002]
    content {
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      security_groups = [aws_security_group.alb_sg.id]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "lks-mart-ecs-sg" }
}

resource "aws_security_group" "rds_sg" {
  name        = "lks-mart-rds-sg"
  description = "SG for RDS MYSQL"
  vpc_id      = aws_vpc.lks_mart_vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "lks-mart-rds-sg" }
}

resource "aws_security_group" "elasticache-sg" {
  name        = "lks-mart-elasticache-sg"
  description = "SG for Redis"
  vpc_id      = aws_vpc.lks_mart_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "lks-mart-elasticache-sg" }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "lks-mart-db-subnet-group"
  description = "For RDS MySQL"
  subnet_ids  = [aws_subnet.priv_sub_a.id, aws_subnet.priv_sub_b.id]

  tags = {
    Name = "lks-mart-db-subnet-group"
  }
}

resource "aws_db_instance" "MySQL" {
  identifier             = "lks-mart-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "cloudmartdb"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  username               = "admin"
  password               = "LKS-CloudMart26!"
  skip_final_snapshot    = true
  publicly_accessible    = false
  multi_az               = false

  tags = {
    Name = "lks-mart-rds"
  }
}

resource "aws_dynamodb_table" "session_table" {
  name         = "lks-mart-session-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    enabled        = true
    attribute_name = "ttl"
  }

  tags = {
    Name = "lks-mart-session-table"
  }
}

resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name        = "lks-mart-elasticache-subnet-group"
  description = "For ElastiCache Redis"
  subnet_ids  = [aws_subnet.priv_sub_a.id, aws_subnet.priv_sub_b.id]

  tags = {
    Name = "lks-mart-elasticache-subnet-group"
  }
}

resource "aws_elasticache_cluster" "Redis" {
  cluster_id         = "lks-mart-redis"
  engine             = "redis"
  engine_version     = "7.1"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  subnet_group_name  = aws_elasticache_subnet_group.elasticache_subnet_group.name
  security_group_ids = [aws_security_group.elasticache-sg.id]
  tags = {
    Name = "lks-mart-redis"
  }

}

locals {
  assets_bucket_name = "lks-mart-assets-blitar-revo"
}

resource "aws_s3_bucket_versioning" "assets_bucket_versioning" {
  bucket = local.assets_bucket_name

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "assets_bucket_pab" {
  bucket = local.assets_bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "DLQ" {
  name                       = "lks-mart-order-events-dlq"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 432000
  tags = {
    Name = "lks-mart-order-events-dlq"
  }
}

resource "aws_sqs_queue" "SQS" {
  name                       = "lks-mart-order-events"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.DLQ.arn
    maxReceiveCount     = 5
  })
  tags = {
    Name = "lks-mart-order-events"
  }
}

resource "aws_sns_topic" "notification" {
  name         = "lks-mart-notifications"
  display_name = "CloudMartNotifications"
  tags         = { Name = "lks-mart-notifications" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notification.arn
  protocol  = "email"
  endpoint  = "schoolrevanoputra@gmail.com"
}

resource "aws_ssm_parameter" "secure" {
  name  = "/lks-mart/db-url"
  type  = "SecureString"
  value = "mysql://admin:LKS-CloudMart26!@${aws_db_instance.MySQL.endpoint}/cloudmartdb"
}
resource "aws_ssm_parameter" "string" {
  for_each = {
    "redis-url"         = "redis://${aws_elasticache_cluster.Redis.cache_nodes[0].address}:6379"
    "sqs-url"           = aws_sqs_queue.SQS.url
    "sns-topic-arn"     = aws_sns_topic.notification.arn
    "s3-bucket"         = local.assets_bucket_name
    "base-url"          = "http://${aws_lb.alb.dns_name}"
    "port-order"        = "3000"
    "port-notification" = "3001"
    "port-inventory"    = "3002"
    "dynamodb-table"    = aws_dynamodb_table.session_table.name
    "dynamodb-region"   = var.aws_region
  }

  name  = "/lks-mart/${each.key}"
  type  = "String"
  value = each.value

  tags = {
    Name = "lks-mart-${each.key}"
  }
}


resource "aws_ecr_repository" "app_repo" {
  for_each             = toset(["order", "notification", "inventory", "frontend"])
  name                 = "lks-mart-${each.value}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = false
  }
  tags = {
    Name = "lks-mart-${each.value}"
  }
}

resource "aws_lb" "alb" {
  name               = "lks-mart-alb"
  internal           = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.pub_sub_a.id,
    aws_subnet.pub_sub_b.id
  ]
  security_groups = [aws_security_group.alb_sg.id]
  tags = {
    Name = "lks-mart-alb"
  }
}

resource "aws_lb_target_group" "frontend" {
  name        = "lks-mart-tg-frontend"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lks_mart_vpc.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
  tags = {
    Name = "lks-mart-tg-frontend"
  }

}

resource "aws_lb_target_group" "order" {
  name        = "lks-mart-tg-order"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lks_mart_vpc.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
  tags = {
    Name = "lks-mart-tg-order"
  }

}

resource "aws_lb_target_group" "notification" {
  name        = "lks-mart-tg-notification"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lks_mart_vpc.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
  tags = {
    Name = "lks-mart-tg-notification"
  }

}

resource "aws_lb_target_group" "inventory" {
  name        = "lks-mart-tg-inventory"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lks_mart_vpc.id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }
  tags = {
    Name = "lks-mart-tg-inventory"
  }

}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  tags = {
    Name = "lks-mart-alb-listener-80"
  }
}

resource "aws_lb_listener_rule" "rules" {
  for_each = {
    "orders" = {
      priority         = 1
      path_pattern     = "/api/orders/*"
      target_group_arn = aws_lb_target_group.order.arn
    }
    "notify" = {
      priority         = 2
      path_pattern     = "/api/notify/*"
      target_group_arn = aws_lb_target_group.notification.arn
    }
    "inventory" = {
      priority         = 3
      path_pattern     = "/api/inventory/*"
      target_group_arn = aws_lb_target_group.inventory.arn
    }
    "api_fallback" = {
      priority         = 4
      path_pattern     = "/api/*"
      target_group_arn = aws_lb_target_group.order.arn
    }
  }

  listener_arn = aws_lb_listener.http.arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = each.value.target_group_arn
  }

  condition {
    path_pattern {
      values = [each.value.path_pattern]
    }
  }

  tags = {
    Name = "lks-mart-rule-${each.key}"
  }
}

# ============================================================
# TAHAP 8: ECS Fargate
# ============================================================

# 1. IAM Role bawaan AWS Academy (LabRole)
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# 2. ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = "lks-mart-cluster"

  tags = {
    Name = "lks-mart-cluster"
  }
}

# 3. CloudWatch Log Groups (Retensi 7 Hari per service dengan for_each)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  for_each          = toset(["order", "notification", "inventory", "frontend"])
  name              = "/ecs/lks-mart-${each.value}"
  retention_in_days = 7

  tags = {
    Name = "lks-mart-log-${each.value}"
  }
}

# ------------------------------------------------------------
# 4. Task Definitions
# ------------------------------------------------------------

# 4.1 Order Service (CPU 512, RAM 1024, Port 3000)
resource "aws_ecs_task_definition" "order" {
  family                   = "lks-mart-order-td"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "order-svc"
      image     = "${aws_ecr_repository.app_repo["order"].repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      secrets = [
        { name = "PORT_ORDER", valueFrom = aws_ssm_parameter.string["port-order"].arn },
        { name = "DB_URL", valueFrom = aws_ssm_parameter.secure.arn },
        { name = "SQS_URL", valueFrom = aws_ssm_parameter.string["sqs-url"].arn },
        { name = "DYNAMODB_TABLE", valueFrom = aws_ssm_parameter.string["dynamodb-table"].arn },
        { name = "DYNAMODB_REGION", valueFrom = aws_ssm_parameter.string["dynamodb-region"].arn },
        { name = "BASE_URL", valueFrom = aws_ssm_parameter.string["base-url"].arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["order"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "lks-mart-order-td"
  }
}

# 4.2 Notification Service (CPU 512, RAM 1024, Port 3001)
resource "aws_ecs_task_definition" "notification" {
  family                   = "lks-mart-notification-td"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "notification-svc"
      image     = "${aws_ecr_repository.app_repo["notification"].repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3001
          hostPort      = 3001
        }
      ]
      secrets = [
        { name = "PORT_NOTIFICATION", valueFrom = aws_ssm_parameter.string["port-notification"].arn },
        { name = "SQS_URL", valueFrom = aws_ssm_parameter.string["sqs-url"].arn },
        { name = "SNS_TOPIC_ARN", valueFrom = aws_ssm_parameter.string["sns-topic-arn"].arn },
        { name = "DYNAMODB_REGION", valueFrom = aws_ssm_parameter.string["dynamodb-region"].arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["notification"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "lks-mart-notification-td"
  }
}

# 4.3 Inventory Service (CPU 512, RAM 1024, Port 3002)
resource "aws_ecs_task_definition" "inventory" {
  family                   = "lks-mart-inventory-td"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "inventory-svc"
      image     = "${aws_ecr_repository.app_repo["inventory"].repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3002
          hostPort      = 3002
        }
      ]
      secrets = [
        { name = "PORT_INVENTORY", valueFrom = aws_ssm_parameter.string["port-inventory"].arn },
        { name = "DB_URL", valueFrom = aws_ssm_parameter.secure.arn },
        { name = "REDIS_URL", valueFrom = aws_ssm_parameter.string["redis-url"].arn },
        { name = "S3_BUCKET", valueFrom = aws_ssm_parameter.string["s3-bucket"].arn }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["inventory"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "lks-mart-inventory-td"
  }
}

# 4.4 Frontend Service (CPU 256, RAM 512, Port 80)
resource "aws_ecs_task_definition" "frontend" {
  family                   = "lks-mart-frontend-td"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.lab_role.arn
  task_role_arn            = data.aws_iam_role.lab_role.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = "${aws_ecr_repository.app_repo["frontend"].repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs["frontend"].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "lks-mart-frontend-td"
  }
}

resource "aws_ecs_service" "services" {
  for_each = {
    order = {
      task_definition  = aws_ecs_task_definition.order.arn
      target_group_arn = aws_lb_target_group.order.arn
      container_name   = "order-svc"
      container_port   = 3000
    }
    notification = {
      task_definition  = aws_ecs_task_definition.notification.arn
      target_group_arn = aws_lb_target_group.notification.arn
      container_name   = "notification-svc"
      container_port   = 3001
    }
    inventory = {
      task_definition  = aws_ecs_task_definition.inventory.arn
      target_group_arn = aws_lb_target_group.inventory.arn
      container_name   = "inventory-svc"
      container_port   = 3002
    }
    frontend = {
      task_definition  = aws_ecs_task_definition.frontend.arn
      target_group_arn = aws_lb_target_group.frontend.arn
      container_name   = "frontend"
      container_port   = 80
    }
  }

  name            = "lks-mart-${each.key}-svc"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = each.value.task_definition
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.priv_sub_a.id, aws_subnet.priv_sub_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = each.value.container_name
    container_port   = each.value.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "lks-mart-${each.key}-svc"
  }
}
