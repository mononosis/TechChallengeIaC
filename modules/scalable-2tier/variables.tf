variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = null
}
variable "environment" {
  description = "Type of deployment environment"
  type        = string
  default     = null
}
variable "vpc_cidr" {
  description = "Cidr block for the VPC"
  type        = string
  default     = null
}
variable "region" {
  description = "Region of the VPC"
  type        = string
  default     = null
}
variable "availability_zones" {
  description = "Availability zone from the chosen region"
  type        = list(string)
  default     = []
}
variable "db_engine" {
  description = "Type of RDS aurora such as aurora-postgresql or aurora-mysql"
  type        = string
  default     = null
}
variable "db_port" {
  description = "DB port number"
  type        = number
  default     = null
}
variable "db_name" {
  description = "Database name"
  type        = string
  default     = null
}
variable "db_username" {
  description = "Database username"
  type        = string
  default     = null
}
variable "app_port" {
  description = "Port of application server"
  type        = number
  default     = null
}
variable "app_host" {
  description = "The host ip where the application is listening from"
  type        = string
  default     = "0.0.0.0"
}
variable "service_task" {
  description = "Region of the VPC"
  type        = list
  default = null
}
variable "scaling_policy_target_value" {
  description = "Region of the VPC"
  type        = number
  default = 50
}

