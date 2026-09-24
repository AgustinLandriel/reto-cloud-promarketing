# ---------------------------------------------------------------------------
# main.tf  ·  Consultas a AWS y valores derivados. No crea recursos.
# ---------------------------------------------------------------------------

locals {
  # Las dos zonas de disponibilidad que exige el reto, escritas a mano.
  azs = ["ca-central-1a", "ca-central-1b"]
}
