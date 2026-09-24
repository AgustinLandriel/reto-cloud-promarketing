
output "alb_dns" {
  description = "DNS del ALB: punto de entrada del trafico de Internet"
  value       = aws_lb.alb_casino.dns_name
}

output "cloudfront_dominio" {
  description = "Dominio de CloudFront desde donde se sirve el contenido estatico"
  value       = aws_cloudfront_distribution.bucket.domain_name
}

output "s3_assets" {
  description = "Bucket privado con el contenido estatico (assets)"
  value       = aws_s3_bucket.bucket.bucket
}

output "s3_logs" {
  description = "Bucket con los access logs del ALB"
  value       = aws_s3_bucket.logs.bucket
}

# --- Red -------------------------------------------------------------------
output "vpc_principal_id" {
  description = "ID de la VPC principal (aplicaciones)"
  value       = module.vpc_prod.vpc_id
}

output "vpc_bodega_id" {
  description = "ID de la VPC de la bodega de datos"
  value       = module.vpc_bodega.vpc_id
}

output "peering_id" {
  description = "ID del VPC Peering entre la VPC principal y la bodega"
  value       = aws_vpc_peering_connection.prod_bodega.id
}

output "nat_ip_publica" {
  description = "IP publica (Elastic IP) por la que salen a Internet las EC2 privadas"
  value       = module.vpc_prod.nat_public_ips
}

# --- Aplicaciones ----------------------------------------------------------
output "ec2_ips_privadas" {
  description = "IP privada de cada EC2, por aplicacion y zona de disponibilidad"
  value = {
    "ca-central-1a" = { for app, ec2 in aws_instance.app_1a : app => ec2.private_ip }
    "ca-central-1b" = { for app, ec2 in aws_instance.app_1b : app => ec2.private_ip }
  }
}

# --- Datos -----------------------------------------------------------------
output "rds_transaccional_endpoint" {
  description = "Endpoint de la RDS transaccional (Multi-AZ)"
  value       = aws_db_instance.transaccional.endpoint
}

output "rds_bodega_endpoint" {
  description = "Endpoint de la RDS historica de la bodega"
  value       = aws_db_instance.bodega.endpoint
}

output "redis_endpoint" {
  description = "Endpoint del nodo primario de Redis"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
