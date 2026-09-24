# ---------------------------------------------------------------------------
# s3 bucket para assets
#
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "bucket" {
  bucket = "s3-bucket-${var.proyecto}-prod-01-cacentral1"

  tags = { Name = "s3-bucket-${var.proyecto}-prod-01-cacentral1" }
}

# Bloquea todo acceso publico: ACLs publicas y politicas publicas.
resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Desactiva las ACL por completo
resource "aws_s3_bucket_ownership_controls" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Permite que solo Cloudfront lea el bucket
resource "aws_s3_bucket_policy" "bucket" {
  bucket = aws_s3_bucket.bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SoloCloudFront"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.bucket.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.bucket.arn }
      }
    }]
  })

  # El bloqueo de acceso publico tiene que estar activo antes que la policy.
  depends_on = [aws_s3_bucket_public_access_block.bucket]
}
