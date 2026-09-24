# ---------------------------------------------------------------------------
# RDS transaccional, Redis y RDS historica de la bodega.
# Los subnet groups los crea el modulo VPC (network.tf).
# ---------------------------------------------------------------------------

# --- RDS transaccional (VPC principal) -------------------------------------
resource "aws_db_instance" "transaccional" {
  identifier     = "rds-${var.proyecto}-prod-01-cacentral1"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.medium"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = var.proyecto
  username = "admin_${var.proyecto}"

  # AWS genera la clave y la guarda en Secrets Manager

  # Multi-AZ: replica sincrona en la otra AZ, con failover automatico.
  multi_az               = true
  db_subnet_group_name   = module.vpc_prod.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = 7

  # Evita que la base se borre por error
  deletion_protection = true

  skip_final_snapshot = false


  tags = { Name = "rds-${var.proyecto}-prod-01-cacentral1" }
}

# --- Redis (ElastiCache) ---------------------------------------------------
# Un Redis principal y una replica, cada uno en una AZ.
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "redis-${var.proyecto}-prod-01-cacentral1"
  description          = "Redis del casino: primario y replica en 2 AZ"

  engine             = "redis"
  node_type          = "cache.t3.micro"
  port               = 6379
  num_cache_clusters = 2

  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = module.vpc_prod.elasticache_subnet_group_name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = { Name = "redis-${var.proyecto}-prod-01-cacentral1" }
}

# --- RDS historica (VPC bodega) --------------------------------------------
# Instancia unica en la AZ a
resource "aws_db_instance" "bodega" {
  identifier     = "rds-${var.proyecto}-bodega-01-cacentral1a"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.medium"

  allocated_storage = 100
  storage_encrypted = true

  db_name  = "${var.proyecto}_historica"
  username = "admin_${var.proyecto}"

  manage_master_user_password = true

  multi_az               = false
  availability_zone      = local.azs[0]
  db_subnet_group_name   = module.vpc_bodega.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_bodega.id]
  publicly_accessible    = false

  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false

  tags = { Name = "rds-${var.proyecto}-bodega-01-cacentral1a" }
}
