output "lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = module.scalable_2tier.lb_dns_name
}
output "cluster_name" {
  description = "The DNS name of the load balancer."
  value       = module.scalable_2tier.ecs_cluster_name
}
output "profile" {
  description = "The DNS name of the load balancer."
  value       = var.aws_profile
}

