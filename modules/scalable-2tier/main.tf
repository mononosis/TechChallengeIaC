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
resource "aws_route_table" "nat_allocated" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    Name = "${var.project_name}-NGW-RT"
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
  route_table_id = aws_route_table.nat_allocated.id
}
#--------------------------------------------------------------------------------------------------
# Sc. Security
#--------------------------------------------------------------------------------------------------
resource "aws_security_group" "db_private_net" {
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
resource "aws_security_group" "web_alb" {
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
resource "aws_security_group" "ecs_tasks" {
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
resource "aws_iam_role_policy_attachment" "ecs_tasks" {
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
