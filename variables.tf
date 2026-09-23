# ---------------------------------------------------------------------------
# variables.tf
# Todo lo configurable del proyecto. La regla que sigue el codigo es simple:
# si un valor se repite o algun dia puede cambiar, es una variable.
# ---------------------------------------------------------------------------

variable "region" {
  description = "Region de AWS. El reto exige ca-central-1 (Canada)."
  type        = string
  default     = "ca-central-1"
}

variable "proyecto" {
  description = "Nombre del proyecto; es el segundo campo del estandar de nombres."
  type        = string
  default     = "casino"
}

# --- Red -------------------------------------------------------------------

variable "vpc_prod_cidr" {
  description = "Rango de la VPC principal, donde viven las aplicaciones."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_bodega_cidr" {
  description = "Rango de la VPC de bodega. No puede solaparse con el de la principal."
  type        = string
  default     = "10.1.0.0/16"
}

variable "subredes_prod" {
  description = "Subredes de la VPC principal: un CIDR por AZ en cada capa (pub, app, redis, database)."
  type        = map(list(string))
  default = {
    pub      = ["10.0.0.0/24", "10.0.1.0/24"]   # ALB y NAT Gateway
    app      = ["10.0.10.0/24", "10.0.11.0/24"] # las 8 EC2
    redis    = ["10.0.20.0/24", "10.0.21.0/24"] # Redis
    database = ["10.0.30.0/24", "10.0.31.0/24"] # RDS transaccional
  }
}

variable "subredes_bodega" {
  description = "Subredes de la bodega. Son dos porque el subnet group de RDS exige dos AZs."
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

# --- Computo ---------------------------------------------------------------

variable "aplicaciones" {
  description = "Las 4 aplicaciones y su tipo de instancia. Cada una va en las 2 AZ (8 EC2)."
  type        = map(string)
  default = {
    frontsite  = "m6i.large"
    backoffice = "t3.medium"
    webapi     = "m6i.large"
    gameapi    = "c6i.large"
  }
}

# --- Bases de datos --------------------------------------------------------

variable "postgres_version" {
  description = "Version mayor de PostgreSQL para las dos bases RDS."
  type        = string
  default     = "16"
}

variable "rds_prod_tipo" {
  description = "Instancia de la base transaccional (familia R, optimizada en memoria)."
  type        = string
  default     = "db.r6i.large"
}

variable "rds_bodega_tipo" {
  description = "Instancia de la base historica (familia M, alcanza para consultas analiticas)."
  type        = string
  default     = "db.m6i.large"
}

variable "rds_prod_storage_gb" {
  description = "Almacenamiento inicial de la base transaccional, en GB."
  type        = number
  default     = 100
}

variable "rds_bodega_storage_gb" {
  description = "Almacenamiento inicial de la base historica, en GB. Mas grande porque acumula historico."
  type        = number
  default     = 250
}

# --- Cache -----------------------------------------------------------------

variable "redis_tipo_nodo" {
  description = "Tipo de nodo de ElastiCache (familia R, Redis vive en memoria)."
  type        = string
  default     = "cache.r6g.large"
}

# --- Entrada y observabilidad ----------------------------------------------

variable "dominio" {
  description = "Dominio para los certificados de ACM y las reglas del ALB."
  type        = string
  default     = "casino-online.example.com"
}

variable "retencion_logs_dias" {
  description = "Dias que CloudWatch conserva los logs (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180 o 365)."
  type        = number
  default     = 30
}
