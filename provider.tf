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

  region = "ca-central-1"

  default_tags {
    tags = {
      Proyecto = var.proyecto
      Gestion  = "terraform"
      Repo     = "reto-cloud-promarketing"
    }
  }
}
