output "cluster_name" {
  description = "Cluster name where fargate tasks and services run"
  value       = aws_ecs_cluster.this.name
}
output "profile" {
  description = "Name specified in the profile flag after aws configure"
  value       = var.aws_profile
}
output "region" {
  description = "AWS Region"
  value       = var.region
}
output "application_url" {
  description = "The DNS name of the load balancer."
  value       = "http://${aws_lb.web.dns_name}"
}
