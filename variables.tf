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
