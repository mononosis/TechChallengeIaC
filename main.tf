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
module "vpc_new" {
  source             = "./modules/scalable-2tier"
  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones

}
