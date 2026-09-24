# ---------------------------------------------------------------------------
# variables.tf
# Todo lo configurable del proyecto. La regla que sigue el codigo es simple:
# si un valor se repite o algun dia puede cambiar, es una variable.
# ---------------------------------------------------------------------------

variable "proyecto" {
  description = "Nombre del proyecto"
  type        = string
  default     = "casino"
}

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

