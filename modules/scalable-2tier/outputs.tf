output "db_password" {
  description = "The secret password for the database"
  sensitive   = true
  value       = random_password.db_password.result
}
