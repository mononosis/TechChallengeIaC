output "lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.web.dns_name
}
output "cluster_name" {
  description = "The DNS name of the load balancer."
  value       = aws_ecs_cluster.this.name
}
output "profile" {
  description = "The DNS name of the load balancer."
  value       = var.aws_profile
}
output "region" {
  description = "The DNS name of the load balancer."
  value       = var.region
}
