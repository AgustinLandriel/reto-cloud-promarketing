# ---------------------------------------------------------------------------
# las EC2 llegan a S3 y a Secrets Manager
# 
# ---------------------------------------------------------------------------

# --- S3 (tipo Gateway) -----------------------------------------------------
# se agrega una ruta a la tabla de rutas de las subredes, y el trafico hacia S3 toma ese camino.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc_prod.vpc_id
  service_name      = "com.amazonaws.ca-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc_prod.private_route_table_ids

  tags = { Name = "endpoint-s3-${var.proyecto}-prod-01-cacentral1" }
}

# --- Secrets Manager (tipo Interface) --------------------------------------

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc_prod.vpc_id
  service_name        = "com.amazonaws.ca-central-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc_prod.private_subnets
  security_group_ids  = [aws_security_group.secretsmanager.id]
  private_dns_enabled = true

  tags = { Name = "endpoint-secretsmanager-${var.proyecto}-prod-01-cacentral1" }
}

# SG del endpoint: solo acepta HTTPS de las apps que leen credenciales
# (las que usan RDS).
resource "aws_security_group" "secretsmanager" {
  name        = "sg-secretsmanager-${var.proyecto}-prod-01-cacentral1"
  description = "Endpoint de Secrets Manager"
  vpc_id      = module.vpc_prod.vpc_id

  tags = { Name = "sg-secretsmanager-${var.proyecto}-prod-01-cacentral1" }
}

resource "aws_vpc_security_group_ingress_rule" "secretsmanager_desde_app" {
  for_each = toset(local.acceso.rds)

  security_group_id            = aws_security_group.secretsmanager.id
  description                  = "Desde ${each.key}"
  referenced_security_group_id = aws_security_group.app[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
