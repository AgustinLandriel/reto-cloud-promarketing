# ---------------------------------------------------------------------------
# Security Groups y NACL
#
# Hay un SG por aplicacion, para dar a cada una solo el acceso que usa
#
# !!! !!!!!!!!!!!!!!!!!!!!!!!!!
# Los puertos de las apps son todos 8080, los puse por default porque no lo encontre especificado en el README
#!!!!!!!!!!!!!!!!!

# Los SG de Redis y RDS no tienen reglas de salida: solo responden.
# ---------------------------------------------------------------------------

locals {
  # Que aplicaciones pueden llegar a cada servicio. Para dar o quitar un
  # acceso basta con editar estas listas.
  acceso = {
    redis  = ["webapi", "gameapi"]
    rds    = ["backoffice", "webapi", "gameapi"]
    bodega = ["backoffice"]
  }
}

# --- ALB -------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "sg-alb-${var.proyecto}-prod-01-cacentral1"
  description = "Balanceador: recibe 80/443 desde Internet"
  vpc_id      = module.vpc_prod.vpc_id

  tags = { Name = "sg-alb-${var.proyecto}-prod-01-cacentral1" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet (se redirige a HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde Internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_hacia_app" {
  for_each = var.aplicaciones

  security_group_id            = aws_security_group.alb.id
  description                  = "Hacia ${each.key}, solo al puerto de la app"
  referenced_security_group_id = aws_security_group.app[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

# --- Aplicaciones (uno por app) --------------------------------------------
resource "aws_security_group" "app" {
  for_each = var.aplicaciones

  name        = "sg-${each.key}-${var.proyecto}-prod-01-cacentral1"
  description = "${each.key}: solo acepta trafico del ALB"
  vpc_id      = module.vpc_prod.vpc_id

  tags = { Name = "sg-${each.key}-${var.proyecto}-prod-01-cacentral1" }
}

# Se referencia el SG del ALB 
resource "aws_vpc_security_group_ingress_rule" "app_desde_alb" {
  for_each = var.aplicaciones

  security_group_id            = aws_security_group.app[each.key].id
  description                  = "Desde el ALB"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 8080
  to_port                      = 8080
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  for_each = var.aplicaciones

  security_group_id = aws_security_group.app[each.key].id
  description       = "HTTPS saliente: NAT, S3 y Secrets Manager (por sus endpoints)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "app_hacia_redis" {
  for_each = toset(local.acceso.redis)

  security_group_id            = aws_security_group.app[each.key].id
  description                  = "Regla de salida hacia Redis"
  referenced_security_group_id = aws_security_group.redis.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

resource "aws_vpc_security_group_egress_rule" "app_hacia_rds" {
  for_each = toset(local.acceso.rds)

  security_group_id            = aws_security_group.app[each.key].id
  description                  = "Regla de entrada hacia RDS transaccional"
  referenced_security_group_id = aws_security_group.rds.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

resource "aws_vpc_security_group_egress_rule" "app_hacia_bodega" {
  for_each = toset(local.acceso.bodega)

  security_group_id            = aws_security_group.app[each.key].id
  description                  = "trafico Hacia RDS historica de la bodega, por el peering"
  referenced_security_group_id = aws_security_group.rds_bodega.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# --- Redis -----------------------------------------------------------------
resource "aws_security_group" "redis" {
  name        = "sg-redis-${var.proyecto}-prod-01-cacentral1"
  description = "Redis: solo acepta a las apps autorizadas, actualmente webapi y gameapi"
  vpc_id      = module.vpc_prod.vpc_id

  tags = { Name = "sg-redis-${var.proyecto}-prod-01-cacentral1" }
}

resource "aws_vpc_security_group_ingress_rule" "redis_desde_app" {
  for_each = toset(local.acceso.redis)

  security_group_id            = aws_security_group.redis.id
  description                  = "Desde ${each.key}"
  referenced_security_group_id = aws_security_group.app[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

# --- RDS transaccional -----------------------------------------------------
resource "aws_security_group" "rds" {
  name        = "sg-rds-${var.proyecto}-prod-01-cacentral1"
  description = "RDS transaccional: solo acepta a las apps autorizadas, backoffice, webapi y gameapi"
  vpc_id      = module.vpc_prod.vpc_id

  tags = { Name = "sg-rds-${var.proyecto}-prod-01-cacentral1" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_desde_app" {
  for_each = toset(local.acceso.rds)

  security_group_id            = aws_security_group.rds.id
  description                  = "Desde ${each.key}"
  referenced_security_group_id = aws_security_group.app[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# --- RDS historica  ------------------------------------------------------------
resource "aws_security_group" "rds_bodega" {
  name        = "sg-rds-${var.proyecto}-bodega-01-cacentral1"
  description = "RDS bodega: solo acepta a las apps autorizadas de la VPC principal, actualmente solo backoffice"
  vpc_id      = module.vpc_bodega.vpc_id

  tags = { Name = "sg-rds-${var.proyecto}-bodega-01-cacentral1" }
}

# El origen es el SG de otra VPC
resource "aws_vpc_security_group_ingress_rule" "rds_bodega_desde_app" {
  for_each = toset(local.acceso.bodega)

  security_group_id            = aws_security_group.rds_bodega.id
  description                  = "Desde ${each.key}"
  referenced_security_group_id = aws_security_group.app[each.key].id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# ---------------------------------------------------------------------------
# NACLs  
#
# ---------------------------------------------------------------------------

# --- Subredes publicas: ALB y NAT ---
resource "aws_network_acl" "pub" {
  vpc_id     = module.vpc_prod.vpc_id
  subnet_ids = module.vpc_prod.public_subnets

  # Entra: Internet al ALB, y las apps hacia el NAT
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Vuelta: respuestas de Internet al NAT y de las apps al ALB
  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Sale: del ALB a las apps
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 8080
    to_port    = 8080
  }
  egress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 8080
    to_port    = 8080
  }

  # Sale: del NAT a Internet, y las respuestas
  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = { Name = "nacl-pub-${var.proyecto}-prod-01-cacentral1" }
}

# --- Subredes app: las EC2 ---
resource "aws_network_acl" "app" {
  vpc_id     = module.vpc_prod.vpc_id
  subnet_ids = module.vpc_prod.private_subnets

  # Entra: el ALB, y las respuestas (NAT, Redis, RDS, bodega, endpoints)
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.0.0/24"
    from_port  = 8080
    to_port    = 8080
  }
  ingress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.1.0/24"
    from_port  = 8080
    to_port    = 8080
  }
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Entra: HTTPS al endpoint de Secrets Manager desde la otra subred app
  ingress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 443
    to_port    = 443
  }
  ingress {
    rule_no    = 121
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 443
    to_port    = 443
  }

  # Sale: a Redis, RDS, bodega y HTTPS
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.20.0/24"
    from_port  = 6379
    to_port    = 6379
  }
  egress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.21.0/24"
    from_port  = 6379
    to_port    = 6379
  }
  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.30.0/24"
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 111
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.31.0/24"
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 120
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.1.10.0/24"
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 121
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.1.11.0/24"
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 130
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Sale: las respuestas al ALB
  egress {
    rule_no    = 140
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.0.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 141
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.1.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  # Sale: respuestas del endpoint a la otra subred app
  egress {
    rule_no    = 150
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 151
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  tags = { Name = "nacl-app-${var.proyecto}-prod-01-cacentral1" }
}

# --- Subredes Redis ---
resource "aws_network_acl" "redis" {
  vpc_id     = module.vpc_prod.vpc_id
  subnet_ids = module.vpc_prod.elasticache_subnets

  # Entra: las apps
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 6379
    to_port    = 6379
  }
  ingress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 6379
    to_port    = 6379
  }

  # Entra: replicacion entre el nodo primario y la replica
  ingress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.20.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  ingress {
    rule_no    = 111
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.21.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  # Sale: respuestas a las apps
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  # Sale: replicacion entre nodos
  egress {
    rule_no    = 110
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.20.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 111
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.21.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  tags = { Name = "nacl-redis-${var.proyecto}-prod-01-cacentral1" }
}

# --- Subredes de la base transaccional ---
resource "aws_network_acl" "database" {
  vpc_id     = module.vpc_prod.vpc_id
  subnet_ids = module.vpc_prod.database_subnets

  # Entra: las apps
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 5432
    to_port    = 5432
  }
  ingress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 5432
    to_port    = 5432
  }

  # Sale: respuestas a las apps
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  tags = { Name = "nacl-database-${var.proyecto}-prod-01-cacentral1" }
}

# --- Subredes de la bodega ( VPC 2 ) ---
resource "aws_network_acl" "bodega" {
  vpc_id     = module.vpc_bodega.vpc_id
  subnet_ids = module.vpc_bodega.database_subnets

  # Entra: las apps de la VPC principal, por el peering
  ingress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 5432
    to_port    = 5432
  }
  ingress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 5432
    to_port    = 5432
  }

  # Sale: respuestas a las apps
  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.10.0/24"
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 101
    action     = "allow"
    protocol   = "tcp"
    cidr_block = "10.0.11.0/24"
    from_port  = 1024
    to_port    = 65535
  }

  tags = { Name = "nacl-database-${var.proyecto}-bodega-01-cacentral1" }
}
