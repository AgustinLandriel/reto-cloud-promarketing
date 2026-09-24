# ---------------------------------------------------------------------------
# Observabilidad: logs de las aplicaciones en CloudWatch,
# access logs del ALB en S3 y alarmas del balanceador.
# ---------------------------------------------------------------------------

# --- CloudWatch Log Groups (uno por aplicacion) ----------------------------


# El CloudWatch Agent de las EC2 envia aca los logs de cada app.
resource "aws_cloudwatch_log_group" "app" {
  for_each = var.aplicaciones

  name              = "cwlog-${each.key}-${var.proyecto}-prod-01-cacentral1"
  retention_in_days = 30

  tags = { Name = "cwlog-${each.key}-${var.proyecto}-prod-01-cacentral1" }
}

# --- Access logs del ALB: bucket S3 ----------------------------------------
resource "aws_s3_bucket" "logs" {
  bucket = "s3-logs-${var.proyecto}-prod-01-cacentral1"

  tags = { Name = "s3-logs-${var.proyecto}-prod-01-cacentral1" }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expirar-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

# Cuenta de AWS que opera los ALB en ca-central-1: es quien envia los logs.
data "aws_elb_service_account" "alb" {}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EscrituraDelALB"
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.alb.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.logs.arn}/alb/AWSLogs/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# --- Alarmas del ALB -------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "alarm-alb-5xx-${var.proyecto}-prod-01-cacentral1"
  alarm_description   = "El ALB devolvio mas de 10 errores 5xx en 5 minutos"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = aws_lb.alb_casino.arn_suffix }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "alb_latencia" {
  alarm_name          = "alarm-alb-latencia-${var.proyecto}-prod-01-cacentral1"
  alarm_description   = "Latencia promedio de las apps mayor a 1 segundo durante 5 minutos"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = aws_lb.alb_casino.arn_suffix }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}
