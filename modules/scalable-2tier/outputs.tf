output "db_password_secret_arn" {
  description = "The secret password for the database"
  value       = aws_secretsmanager_secret.db_password.arn
}
output "db_port" {
  description = "The secret password for the database"
  value       = var.db_port
}
output "db_username" {
  description = "The secret password for the database"
  value       = var.db_username
}
output "db_name" {
  description = "The secret password for the database"
  value       = var.db_name
}
output "db_host" {
  description = "The secret password for the database"
  value       = aws_rds_cluster.this.endpoint
}
output "app_port" {
  description = "The secret password for the database"
  value       = var.app_port
}
output "ecs_tasks_arn" {
  description = "Amazon Resource Name for the ecs tasks"
  value       = aws_iam_role.ecs_tasks.arn
}
output "log_group" {
  description = "Amazon Resource Name for the ecs tasks"
  value       = aws_cloudwatch_log_group.this.name
}
output "ecs_cluster_name" {
  description = "Ecs cluster name"
  value       = aws_ecs_cluster.this.name
}
output "private_subnet_ids" {
  description = "Private subnet"
  value       = aws_subnet.private.*.id
}
output "web_alb_sg_id" {
  description = "Private subnet"
  value       = aws_security_group.web.id
}
output "project_name" {
  description = "Private subnet"
  value       = var.project_name
}
output "lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.web.dns_name
}
