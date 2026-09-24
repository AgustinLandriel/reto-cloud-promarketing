# ---------------------------------------------------------------------------
# Las dos VPC, sus subredes y el peering entre ellas.
# Se usa el modulo oficial terraform-aws-modules/vpc
# ---------------------------------------------------------------------------

module "vpc_prod" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "vpc-${var.proyecto}-prod-01-cacentral1"
  cidr = "10.0.0.0/16"
  azs  = local.azs

  #Divido las subredes en 4 grupos: publicas, privadas, redis y bd. Cada grupo tiene su propia tabla de rutas y su propio SG.

  public_subnets      = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnets     = ["10.0.10.0/24", "10.0.11.0/24"]
  elasticache_subnets = ["10.0.20.0/24", "10.0.21.0/24"]
  database_subnets    = ["10.0.30.0/24", "10.0.31.0/24"]

  public_subnet_names = [
    "subnet-pub-${var.proyecto}-prod-01-cacentral1a",
    "subnet-pub-${var.proyecto}-prod-01-cacentral1b",
  ]

  private_subnet_names = [
    "subnet-app-${var.proyecto}-prod-01-cacentral1a",
    "subnet-app-${var.proyecto}-prod-01-cacentral1b",
  ]

  elasticache_subnet_names = [
    "subnet-redis-${var.proyecto}-prod-01-cacentral1a",
    "subnet-redis-${var.proyecto}-prod-01-cacentral1b",
  ]

  database_subnet_names = [
    "subnet-database-${var.proyecto}-prod-01-cacentral1a",
    "subnet-database-${var.proyecto}-prod-01-cacentral1b",
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Un solo NAT para las dos AZ: 
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tablas de ruta propias para la bd y redis
  create_database_subnet_route_table    = true
  create_elasticache_subnet_route_table = true

  create_database_subnet_group    = true
  create_elasticache_subnet_group = true
  database_subnet_group_name      = "databasesng-${var.proyecto}-prod-01-cacentral1"
  elasticache_subnet_group_name   = "redissng-${var.proyecto}-prod-01-cacentral1"


  igw_tags         = { Name = "igw-${var.proyecto}-prod-01-cacentral1" }
  nat_gateway_tags = { Name = "nat-${var.proyecto}-prod-01-cacentral1a" }
  nat_eip_tags     = { Name = "eip-${var.proyecto}-prod-01-cacentral1a" }
}

module "vpc_bodega" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "vpc-${var.proyecto}-bodega-01-cacentral1"
  cidr = "10.1.0.0/16"
  azs  = local.azs

  database_subnets = ["10.1.10.0/24", "10.1.11.0/24"]
  database_subnet_names = [
    "subnet-database-${var.proyecto}-bodega-01-cacentral1a",
    "subnet-database-${var.proyecto}-bodega-01-cacentral1b",
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Sin IGW y sin NAT
  create_igw         = false
  enable_nat_gateway = false

  create_database_subnet_route_table = true
  create_database_subnet_group       = true
  database_subnet_group_name         = "databasesng-${var.proyecto}-bodega-01-cacentral1"
}


# VPC Peering entre la VPC principal y la VPC de bodega
resource "aws_vpc_peering_connection" "prod_bodega" {
  vpc_id      = module.vpc_prod.vpc_id
  peer_vpc_id = module.vpc_bodega.vpc_id
  auto_accept = true

  tags = {
    Name = "pcx-${var.proyecto}-prod-01-cacentral1"
  }
}

resource "aws_route" "prod_hacia_bodega" {
  route_table_id            = module.vpc_prod.private_route_table_ids[0]
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_bodega.id
}

resource "aws_route" "bodega_hacia_prod" {
  route_table_id            = module.vpc_bodega.database_route_table_ids[0]
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_bodega.id
}
