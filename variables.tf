variable "organisation" {
  description = "Name of the organisation or company"
  type        = string
  default     = null
}
variable "project" {
  description = "Name of the project"
  type        = string
  default     = null
}
variable "environment" {
  description = "Type of environment such as production, staging, testing etc"
  type        = string
  default     = null
}
variable "aws_profile" {
  description = "Name specified in the profile flag after aws configure"
  type        = string
  default     = "default"
}
variable "vpc_cidr" {
  description = "Cidr block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "region" {
  description = "Region of the VPC"
  type        = string
  default     = "ap-southeast-2"
}
variable "app_image_repository" {
  description = "The repository name or registry URL"
  type        = string
  default     = "servian"
}
variable "app_image_name" {
  description = "Name of the application image"
  type        = string
  default     = "techchallengeapp"
}
variable "app_image_tag" {
  description = "Tag or version of the application image"
  type        = string
  default     = "latest"
}
variable "db_engine" {
  description = "Type of RDS aurora such as aurora-postgresql or aurora-mysql"
  type        = string
  default     = "aurora-postgresql"
}
variable "db_port" {
  description = "DB port number"
  type        = number
  default     = 5432
}
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "app"
}
variable "db_username" {
  description = "Database username"
  type        = string
  default     = "principal"
}
variable "app_port" {
  description = "Port of application server"
  type        = number
  default     = 8080
}
variable "app_host" {
  description = "The host ip where the application is listening from"
  type        = string
  default     = "0.0.0.0"
}
variable "scaling_policy_target_value" {
  description = "The average capacity already utilised expressed in percentages"
  type        = number
  default     = null
}
variable "min_capacity" {
  description = "The minimum number of tasks to be running"
  type        = number
  default     = null
}
variable "max_capacity" {
  description = "The maximum number of tasks to be running"
  type        = number
  default     = null
}
variable "task_def_cpu" {
  description = "The number of CPU units for the container"
  type        = number
  default     = 256
}
variable "task_def_memory" {
  description = "The size of memory for the container"
  type        = number
  default     = 512
}
variable "minimum_acu_range" {
  description = "The minimum Aurora capacity unit"
  type        = number
  default     = 2
}
variable "maximum_acu_range" {
  description = "The minimum Aurora capacity unit"
  type        = number
  default     = 8
}
