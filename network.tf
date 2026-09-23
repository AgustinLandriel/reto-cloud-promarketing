# ---------------------------------------------------------------------------
# network.tf  ·  Las dos VPC, sus subredes y el peering entre ellas.
#
# Se usa el modulo oficial terraform-aws-modules/vpc
# ---------------------------------------------------------------------------

module "vpc_prod" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "vpc-${var.proyecto}-prod-01-cacentral1"
  cidr = var.vpc_prod_cidr //10.0.0.0/16
  azs  = local.azs


  public_subnets      = var.subredes_prod["pub"]
  private_subnets     = var.subredes_prod["app"]
  elasticache_subnets = var.subredes_prod["redis"]
  database_subnets    = var.subredes_prod["database"]

  public_subnet_names      = [for i in [1, 2] : "subnet-pub-${var.proyecto}-prod-0${i}-cacentral1"]
  private_subnet_names     = [for i in [1, 2] : "subnet-app-${var.proyecto}-prod-0${i}-cacentral1"]
  elasticache_subnet_names = [for i in [1, 2] : "subnet-redis-${var.proyecto}-prod-0${i}-cacentral1"]
  database_subnet_names    = [for i in [1, 2] : "subnet-database-${var.proyecto}-prod-0${i}-cacentral1"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Un solo NAT para las dos AZ: 
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tablas de ruta propias para cache y datos, sin ruta al NAT: ni Redis ni
  # RDS necesitan Internet, y lo que no tiene ruta no hay que filtrarlo.
  create_database_subnet_route_table    = true
  create_elasticache_subnet_route_table = true

  create_database_subnet_group    = true
  create_elasticache_subnet_group = true
  database_subnet_group_name      = "databasesng-${var.proyecto}-prod-01-cacentral1"
  elasticache_subnet_group_name   = "redissng-${var.proyecto}-prod-01-cacentral1"

  # El modulo nombra IGW, NAT y EIP a partir de "name"; estas etiquetas se
  # aplican despues del valor por defecto, asi que imponen el estandar.
  igw_tags         = { Name = "igw-${var.proyecto}-prod-01-cacentral1" }
  nat_gateway_tags = { Name = "nat-${var.proyecto}-prod-01-cacentral1" }
  nat_eip_tags     = { Name = "eip-${var.proyecto}-prod-01-cacentral1" }
}

module "vpc_bodega" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "vpc-${var.proyecto}-bodega-01-cacentral1"
  cidr = var.vpc_bodega_cidr
  azs  = local.azs

  database_subnets      = var.subredes_bodega
  database_subnet_names = [for i in [1, 2] : "subnet-database-${var.proyecto}-bodega-0${i}-cacentral1"]

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Sin IGW y sin NAT: esta VPC no tiene forma de salir a Internet ni de
  # ser alcanzada desde afuera. Se llega solo por el peering.
  create_igw         = false
  enable_nat_gateway = false

  create_database_subnet_route_table = true
  create_database_subnet_group       = true
  database_subnet_group_name         = "databasesng-${var.proyecto}-bodega-01-cacentral1"
}

resource "aws_vpc_peering_connection" "prod_bodega" {
  vpc_id      = module.vpc_prod.vpc_id
  peer_vpc_id = module.vpc_bodega.vpc_id
  auto_accept = true

  tags = {
    Name = "pcx-${var.proyecto}-prod-01-cacentral1"
  }
}

# Las rutas van en AMBOS sentidos. Si falta una, el peering queda "active"
# pero el trafico no pasa, y se diagnostica mal porque todo parece bien.
#
# Va con count y no con for_each: los IDs de tabla de ruta no se conocen
# hasta el apply, y for_each necesita sus claves ya en el plan.
resource "aws_route" "prod_hacia_bodega" {
  count = length(module.vpc_prod.private_route_table_ids)

  route_table_id            = module.vpc_prod.private_route_table_ids[count.index]
  destination_cidr_block    = var.vpc_bodega_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_bodega.id
}

resource "aws_route" "bodega_hacia_prod" {
  count = length(module.vpc_bodega.database_route_table_ids)

  route_table_id            = module.vpc_bodega.database_route_table_ids[count.index]
  destination_cidr_block    = var.vpc_prod_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.prod_bodega.id
}
