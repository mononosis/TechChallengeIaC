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
module "scalable_2tier" {
  source             = "./modules/scalable-2tier"
  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  db_engine          = "aurora-postgresql"
  db_port            = 5432
  availability_zones = ["ap-southeast-2c", "ap-southeast-2a"]
  app_port           = 8080
}
