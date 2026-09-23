# ---------------------------------------------------------------------------
# main.tf  ·  Consultas a AWS y valores derivados. No crea recursos.
# ---------------------------------------------------------------------------

# Necesario para que el nombre del bucket S3 sea unico a nivel mundial.
data "aws_caller_identity" "actual" {}

locals {
  # Las dos zonas de disponibilidad que exige el reto, escritas a mano.
  azs = ["ca-central-1a", "ca-central-1b"]
}
