# ---------------------------------------------------------------------------
# Application Load Balancer y Enrutamiento
# ---------------------------------------------------------------------------

# El Balanceador 
resource "aws_lb" "alb_casino" {
  name               = "alb-${var.proyecto}-prod-01-cacentral1"
  internal           = false # Se expone hacia internet
  load_balancer_type = "application"

  # Usamos el Security Group creado en  sg.tf
  security_groups = [aws_security_group.alb.id]

  subnets = module.vpc_prod.public_subnets

  # Access logs hacia el bucket de monitoring.tf
  access_logs {
    bucket  = aws_s3_bucket.logs.id
    prefix  = "alb"
    enabled = true
  }

  # La policy del bucket tiene que existir antes de activar los logs.
  depends_on = [aws_s3_bucket_policy.logs]

  tags = { Name = "alb-${var.proyecto}-prod-01-cacentral1" }
}

#Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "tg-app-${var.proyecto}-prod-01-cacentral1"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc_prod.vpc_id

  # Monitoreo de salud de las instancias EC2
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 15
  }
}

#Listener HTTP: Redirección obligatoria a HTTPS
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.alb_casino.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

#Listener HTTPS y  desvío al Target Group 
resource "aws_lb_listener" "https_forward" {
  load_balancer_arn = aws_lb.alb_casino.arn
  port              = "443"
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn = aws_acm_certificate.alb_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

