# ---------------------------------------------------------------------------
# Certificado SSL para el Balanceador
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "alb_cert" {
  # En un entorno real se usaría el dominio comprado.
  domain_name = "dominio.ejemplo.com"

  validation_method = "DNS"

  tags = { Name = "cert-alb-${var.proyecto}-prod-01-cacentral1" }

  lifecycle {

    create_before_destroy = true
  }
}
