provider "aws" {
  profile = var.aws_profile
  region  = var.region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
    }
  }
}

locals {
  standalone_task_config = {
    network_config = {
      awsvpcConfiguration : {
        assignPublicIp = "DISABLED"
        subnets        = module.scalable_2tier.private_subnet_ids
        securityGroups = [module.scalable_2tier.web_alb_sg_id]
      }
    }
  }
  task = {
    name      = var.project_name
    image     = "${var.app_image_repository}/${var.app_image_name}:${var.app_image_tag}"
    essential = true

    environment = [
      { name = "VTT_DBUSER", value = module.scalable_2tier.db_username },
      { name = "VTT_DBNAME", value = module.scalable_2tier.db_name },
      { name = "VTT_DBPORT", value = tostring(module.scalable_2tier.db_port) },
      { name = "VTT_LISTENHOST", value = var.app_host },
      { name = "VTT_LISTENPORT", value = tostring(module.scalable_2tier.app_port) },
      { name = "VTT_DBHOST", value = module.scalable_2tier.db_host }
    ],
    secrets = [
      {
        name      = "VTT_DBPASSWORD",
        valueFrom = module.scalable_2tier.db_password_secret_arn
      },
    ],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = module.scalable_2tier.log_group,
        awslogs-region        = var.region
        awslogs-stream-prefix = "awslogs-${var.project_name}"
      }
    },
    portMappings = [
      {
        containerPort = module.scalable_2tier.app_port
      }
    ]
  }
  service_task = [merge(local.task, var.long_running_task_command)]
  standalone_task   = [merge(local.task, var.standalone_task_command)]
}

module "scalable_2tier" {
  source               = "./modules/scalable-2tier"
  project_name         = var.project_name
  environment          = var.environment
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  db_engine            = "aurora-postgresql"
  db_port              = 5432
  availability_zones   = ["ap-southeast-2c", "ap-southeast-2a"]
  app_port             = 8081
  db_username          = "principal"
  db_name              = "app"
  service_task = local.service_task

}

resource "aws_ecs_task_definition" "standalone" {
  family       = "${var.project_name}-standalone-family"
  network_mode = "awsvpc"

  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = module.scalable_2tier.ecs_tasks_arn
  task_role_arn            = module.scalable_2tier.ecs_tasks_arn

  container_definitions = jsonencode(local.standalone_task)
}

resource "null_resource" "task_one_off" {
  provisioner "local-exec" {
    command = <<EOC
      aws ecs  run-task \
                --cluster ${module.scalable_2tier.ecs_cluster_name} \
                --launch-type FARGATE \
                --region ${var.region} \
                --task-definition ${aws_ecs_task_definition.standalone.family} \
                --network-configuration '${jsonencode(local.standalone_task_config.network_config)}' \
                --started-by "Terraform" 
EOC
  }
}
