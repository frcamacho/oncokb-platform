output "endpoint" {
  description = "RDS instance endpoint (hostname:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS instance hostname only"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Master database username"
  value       = aws_db_instance.this.username
}

output "master_password" {
  description = "Generated master password (sensitive)"
  value       = random_password.master.result
  sensitive   = true
}

output "instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.this.id
}
