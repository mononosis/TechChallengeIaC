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
