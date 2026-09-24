# ---------------------------------------------------------------------------
# Las 8 EC2: 4 aplicaciones x 2 AZ, en las subredes app.
# 
# ---------------------------------------------------------------------------

# Imagen mas reciente de Amazon Linux 2023.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# --- Rol de las EC2: SSM y CloudWatch (logs) -------
resource "aws_iam_role" "ec2" {
  name = "role-ec2-${var.proyecto}-prod-01-cacentral1"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Decidi poner acceso por SSM y no por SSH, porque es mas seguro: no hay que abrir el puerto 22 en el SG, y no hay que manejar claves privadas.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

## Politica para que las EC2 puedan enviar logs a CloudWatch. Se adjunta al rol de las EC2.
resource "aws_iam_role_policy_attachment" "ec2" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "profile-ec2-${var.proyecto}-prod-01-cacentral1"
  role = aws_iam_role.ec2.name
}

# --- Las instancias --------------------------------------------------------
# Cada bloque recorre las 4 apps: uno para la AZ 1a y otro para la AZ 1b.
resource "aws_instance" "app_1a" { # Esto seria ca-central-1a
  for_each = var.aplicaciones

  ami                    = data.aws_ami.al2023.id
  instance_type          = each.value
  subnet_id              = module.vpc_prod.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.app[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "ec2-${each.key}-${var.proyecto}-prod-01-cacentral1a" }
}

resource "aws_instance" "app_1b" { # Esto seria ca-central-1b
  for_each = var.aplicaciones

  ami                    = data.aws_ami.al2023.id
  instance_type          = each.value
  subnet_id              = module.vpc_prod.private_subnets[1]
  vpc_security_group_ids = [aws_security_group.app[each.key].id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "ec2-${each.key}-${var.proyecto}-prod-01-cacentral1b" }
}

# Vinculo las EC2 al balanceador
resource "aws_lb_target_group_attachment" "app_1a" {
  for_each = aws_instance.app_1a

  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = each.value.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "app_1b" {
  for_each = aws_instance.app_1b

  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = each.value.id
  port             = 8080
}
