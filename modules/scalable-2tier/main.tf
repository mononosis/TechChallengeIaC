/*
        SCALABLE 2-TIER (Client + Database)
*/
#--------------------------------------------------------------------------------------------------------------------
# Sc. Network
#--------------------------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.project_name}-VPC"
  }
}
resource "aws_eip" "this" {
  vpc = true
  tags = {
    Name = "${var.project_name}-EIP"
  }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-IGW"
  }
}
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.0.id
  tags = {
    Name = "${var.project_name}-NGW"
  }
}
resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  propagating_vgws       = []
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.project_name}-IGW-RT"
  }
}
resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    Name = "${var.project_name}-NGW-RT"
  }

}
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index * 2)
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(var.availability_zones, count.index)
  tags = {
    Name = "${var.project_name}-${trimprefix(element(var.availability_zones, count.index), var.region)}-PUB-SN"
  }
}
resource "aws_subnet" "private" {
  count                   = length(var.availability_zones)
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, (count.index * 2) + 1)
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(var.availability_zones, count.index)
  tags = {
    Name = "${var.project_name}-${trimprefix(element(var.availability_zones, count.index), var.region)}-PRIV-SN"
  }
}
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public.*)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_default_route_table.this.id
}
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private.*)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.this.id
}
#--------------------------------------------------------------------------------------------------
# Sc. Security
#--------------------------------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name   = var.db_engine
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = {
    Name = "${var.project_name}-DB-SG"
  }
}
resource "aws_security_group" "web" {
  name   = "web-alb"
  vpc_id = aws_vpc.this.id

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

  tags = {
    Name = "${var.project_name}-ALB-SG"
  }
}
resource "aws_security_group" "app" {
  name   = "ecs-tasks"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [cidrsubnet(var.vpc_cidr, 8, 0)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-Tasks-SG"
  }
}
resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.ecs_tasks.name
  policy_arn = data.aws_iam_policy.ecs_tasks.arn
}
data "aws_iam_policy" "ecs_tasks" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
data "aws_iam_policy_document" "db_password_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.db_password.arn]
  }
}
resource "aws_iam_role" "ecs_tasks" {
  name = "ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name   = "DBSecretReadOnly"
    policy = data.aws_iam_policy_document.db_password_secret.json
  }

  tags = {
    Name = "${var.project_name}-ECS-Tasks-Role"
  }
}
resource "aws_secretsmanager_secret" "db_password" {
  name        = "db_password_${random_id.secret_name_postfix.dec}"
  description = "DB password secret for the ecs tasks to retrieve at runtime"
}
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
resource "random_id" "secret_name_postfix" {
  byte_length = 8
}
resource "random_password" "db_password" {
  length  = 16
  special = false
}
#--------------------------------------------------------------------------------------------------
# Sc. Main
#--------------------------------------------------------------------------------------------------
resource "aws_lb" "web" {
  name                             = "web-alb"
  load_balancer_type               = "application"
  internal                         = false
  enable_cross_zone_load_balancing = true

  security_groups = [aws_security_group.web.id]
  subnets = aws_subnet.public.*.id

}
resource "aws_lb_target_group" "http" {
  name        = "http"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "ip"
  health_check {
    path = "/healthcheck/"
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  protocol          = "HTTP"
  port              = "80"

  default_action {
    target_group_arn = aws_lb_target_group.http.arn
    type             = "forward"
  }
}
resource "aws_db_subnet_group" "private" {
  name       = "private-subnet-group"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${var.project_name}-PRIV-SNG"
  }
}
resource "aws_rds_cluster" "this" {
  cluster_identifier   = "aurora-cluster"
  availability_zones   = var.availability_zones
  database_name        = var.db_name
  master_username      = var.db_username
  master_password      = random_password.db_password.result
  engine               = var.db_engine
  db_subnet_group_name = aws_db_subnet_group.private.name
  engine_mode          = "serverless"

  enabled_cloudwatch_logs_exports = []

  skip_final_snapshot = true
  apply_immediately   = true

  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = "${var.project_name}-SERVERLES-RDS"
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      availability_zones,
    ]
  }
  scaling_configuration {
    min_capacity = 2
  }
}
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}Cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_service" "this" {
  name            = "fargate-service"
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = var.project_name
    container_port   = var.app_port
  }

  network_configuration {
    subnets         = aws_subnet.private.*.id
    security_groups = [aws_security_group.app.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.this,
    aws_secretsmanager_secret_version.db_password
  ]
}
resource "aws_ecs_task_definition" "this" {
  family       = "${var.project_name}-family"
  network_mode = "awsvpc"

  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_tasks.arn
  task_role_arn            = aws_iam_role.ecs_tasks.arn

  container_definitions = jsonencode(var.service_task)
}
resource "aws_cloudwatch_log_group" "this" {
  name = var.project_name
}
resource "aws_appautoscaling_target" "this" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "this" {
  name               = "scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = var.scaling_policy_target_value
  }
}
