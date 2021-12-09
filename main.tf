/*
--------------------------------------------------------------------------------------------

        AWS Main Declaration Resources 

        Description: The following resource declarations make use of different AWS services 
        for networking, security and their integration with a 2-tier architecture with 
        auto scaling policies for resiliency at periods of traffic spikes.

        Name Tagging: ${environment}.${organisation}.${project}.${generic-name}

        Networking: 

                Consist of the creation of a new VPC with 2 subnets per availability 
                zone one for public and private respectively. Private net will have 
                access to the internet by associating the NAT gateway and private 
                subnets in a route table. The public subnets will be used mainly for 
                an application load balancer so the app can accessed from the internet. 

        Security: 
                
                The security section comprise the declaration of resources such as roles
                security groups and a secret manager. Roles will be used by fargate so it 
                may have the authority to fetch a database password from a secret 
                manager, write logs to CloudWatch and operate within the service cluster. 
                Security groups will expose to the internet port 80. Application port
                as well as db port will be exposed within the VPC network range. 

        Main: 

                The rest of declared resources integrates a 2-tier architecture and make 
                used of security and networking services. The integration consist of a load 
                balancer, an ecs cluster running fargate tasks with auto scaling policies 
                which triggers on a target value expressed in percentages the cpu average 
                utilisation. Lastly it uses RDS Aurora in serverless mode which also scales 
                its RAM capacity on demand. 
                
        


--------------------------------------------------------------------------------------------
*/
provider "aws" {
  profile = var.aws_profile
  region  = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
    }
  }
}
locals {
  # Used in the Name tag
  tag_prefix_name = "${var.environment}.${var.organisation}.${var.project}"
  # Used in the resource name attribute
  res_prefix_name = "${var.project}"
  # Used in the  network-configuration argument from aws cli  to create a 
  # standalone fargate service
  standalone_task_config = {
    network_config = {
      awsvpcConfiguration : {
        assignPublicIp = "DISABLED"
        subnets        = aws_subnet.private.*.id
        securityGroups = [aws_security_group.web.id]
      }
    }
  }
  # Partial configuration for a fargate tasks. Needs to merge with the propery 
  # command
  task = {
    name      = var.project
    image     = "${var.app_image_repository}/${var.app_image_name}:${var.app_image_tag}"
    essential = true

    environment = [
      { name = "VTT_DBUSER", value = var.db_username },
      { name = "VTT_DBNAME", value = var.db_name },
      { name = "VTT_DBPORT", value = tostring(var.db_port) },
      { name = "VTT_LISTENHOST", value = var.app_host },
      { name = "VTT_LISTENPORT", value = tostring(var.app_port) },
      { name = "VTT_DBHOST", value = aws_rds_cluster.this.endpoint }
    ],
    secrets = [
      {
        name      = "VTT_DBPASSWORD",
        valueFrom = aws_secretsmanager_secret.db_password.arn
      },
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name,
        awslogs-region        = var.region
        awslogs-stream-prefix = "awslogs-${var.project}"
      }
    },
    portMappings = [
      {
        containerPort = var.app_port
      }
    ]
  }

  service_task_command    = { command = ["serve"] }
  standalone_task_command = { command = ["updatedb", "-s"] }

  # Completed task configuration and ready  to be used by  a cluster  service
  # service task is used to run  the app with  the serve  command. Standalone
  # task will only run once to initialise the database and create the schema.
  service_task    = [merge(local.task, local.service_task_command)]
  standalone_task = [merge(local.task, local.standalone_task_command)]

}
#--------------------------------------------------------------------------------------------------------------------
# Sc. Network
#--------------------------------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${local.tag_prefix_name}.vpc"
  }
}
resource "aws_eip" "this" {
  vpc = true
  tags = {
    Name = "${local.tag_prefix_name}.eip"
  }
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.tag_prefix_name}.igw"
  }
}
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public.0.id
  tags = {
    Name = "${local.tag_prefix_name}.ngw"
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
    Name = "${local.tag_prefix_name}.igw-rt"
  }
}
resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    Name = "${local.tag_prefix_name}.ngw-rt"
  }

}
data "aws_availability_zones" "this" {
  state = "available"
}
resource "aws_subnet" "public" {
  count                   = length(data.aws_availability_zones.this.names)
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index * 2)
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(data.aws_availability_zones.this.names, count.index)
  tags = {
    Name = "${local.tag_prefix_name}.public-subnet"
  }
}
resource "aws_subnet" "private" {
  count                   = length(data.aws_availability_zones.this.names)
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, (count.index * 2) + 1)
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = "true"
  availability_zone       = element(data.aws_availability_zones.this.names, count.index)
  tags = {
    Name = "${local.tag_prefix_name}.private-subnet"
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
  name = "${local.res_prefix_name}.${var.db_engine}"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = var.db_port
    to_port     = var.db_port
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }
  tags = {
    Name = "${local.res_prefix_name}.db-sg"
  }
}
resource "aws_security_group" "web" {
  name = "${local.res_prefix_name}.web-alb"
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
    Name = "${local.tag_prefix_name}.web-sg"
  }
}
resource "aws_security_group" "app" {
  name = "${local.res_prefix_name}.app"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [cidrsubnet(aws_vpc.this.cidr_block, 8, 0)]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.tag_prefix_name}.app-sg"
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
  name = "${local.res_prefix_name}.ecs-task-role"

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
    Name = "${local.tag_prefix_name}.ecs-task-role"
  }
}
resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.res_prefix_name}.db-password-${random_id.secret_name_postfix.dec}"
  description = "DB password secret for the ecs tasks to retrieve at runtime"
}
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}
# Secrets will take some time to be deleted so it is necessary to create a 
# name with random postfix in order to create and destroy infrastructure 
# without conflict names.
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
  name = "${local.res_prefix_name}-web-alb"
  load_balancer_type               = "application"
  internal                         = false
  enable_cross_zone_load_balancing = true

  security_groups = [aws_security_group.web.id]
  subnets         = aws_subnet.public.*.id

}
resource "aws_lb_target_group" "http" {
  name = "${local.res_prefix_name}-http"
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
  name = "${local.res_prefix_name}.private"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name = "${local.tag_prefix_name}.db-private-subnet-group"
  }
}
resource "aws_rds_cluster" "this" {
  cluster_identifier   = "aurora-cluster"
  availability_zones   = data.aws_availability_zones.this.names
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
    Name = "${local.tag_prefix_name}.aurora-rds-cluster"
  }

  lifecycle {
    ignore_changes = [
      availability_zones,
    ]
  }
  scaling_configuration {
    min_capacity = var.minimum_acu_range
    max_capacity = var.maximum_acu_range
  }
}
resource "aws_ecs_cluster" "this" {
  name = "${local.res_prefix_name}_ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_service" "this" {
  name = "${local.res_prefix_name}_ecs-service"
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 2

  load_balancer {
    target_group_arn = aws_lb_target_group.http.arn
    container_name   = var.project
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
resource "aws_ecs_task_definition" "service" {
  family       = "${local.res_prefix_name}_service"
  network_mode = "awsvpc"

  cpu                      = var.task_def_cpu
  memory                   = var.task_def_memory
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_tasks.arn
  task_role_arn            = aws_iam_role.ecs_tasks.arn

  container_definitions = jsonencode(local.service_task)
}
resource "aws_cloudwatch_log_group" "this" {
  name = "${local.res_prefix_name}"
}
resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
# The auto scaling policy for fargate tasks will use the average CPU 
# utilisation and trigger if the target value is exceeded.  
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
# The following two stanzas declare and run a one off tasks in order to 
# initialise the database with the schema and create some records. .
resource "aws_ecs_task_definition" "standalone" {
  family       = "${local.res_prefix_name}_standalone"
  network_mode = "awsvpc"

  cpu                      = var.task_def_cpu
  memory                   = var.task_def_memory
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_tasks.arn
  task_role_arn            = aws_iam_role.ecs_tasks.arn

  container_definitions = jsonencode(local.standalone_task)
}
resource "null_resource" "task_one_off" {
  provisioner "local-exec" {
    command = <<EOC
      aws ecs  run-task \
                --cluster ${aws_ecs_cluster.this.name} \
                --launch-type FARGATE \
                --region ${var.region} \
                --task-definition ${aws_ecs_task_definition.standalone.family} \
                --network-configuration '${jsonencode(local.standalone_task_config.network_config)}' \
                --started-by "Terraform" 
EOC
  }
}
