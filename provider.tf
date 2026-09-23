terraform {

  required_version = ">= 1.10"

  required_providers {
    aws = {

      source = "hashicorp/aws"

      version = "~> 6.0"
    }
  }
}

provider "aws" {

  region = var.region


  default_tags {
    tags = {
      Proyecto = var.proyecto
      Gestion  = "terraform"
      Repo     = "reto-cloud-promarketing"
    }
  }
}

# Segundo proveedor, obligatorio por una limitacion de AWS: CloudFront es
# un servicio global y SOLO lee certificados de ACM alojados en us-east-1,
# aunque el resto de la infraestructura viva en Canada. Por eso el proyecto
# necesita dos certificados: uno en ca-central-1 para el ALB y otro aqui.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Proyecto = var.proyecto
      Gestion  = "terraform"
      Repo     = "reto-cloud-promarketing"
    }
  }
}
