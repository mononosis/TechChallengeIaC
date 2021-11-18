variable "aws_profile" {
  description = "Name specified in the profile flag after aws configure"
  type        = string
  default     = "default"
}
variable "project_name" {
  description = "Value of the Name tag for the VPC"
  type        = string
  default     = "TechChallengeApp"
}
variable "environment" {
  description = "Value of the Name tag for the VPC"
  type        = string
  default     = "Production"
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
variable "availability_zones" {
  description = "Region of the VPC"
  type        = list(any)
  default     = ["ap-southeast-2c", "ap-southeast-2a"]
}
variable "app_host" {
  description = "The host ip where the application is listening from"
  type        = string
  default     = "0.0.0.0"
}
variable "long_running_task_command" {
  description = "Region of the VPC"
  type        = map(any)
  default = {
    command = ["serve"]
  }
}
variable "standalone_task_command" {
  description = "Region of the VPC"
  type        = map(any)
  default = {
    command = ["updatedb", "-s"]
  }
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
