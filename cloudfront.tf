# ---------------------------------------------------------------------------
# cloudfront.tf  ·  CDN que sirve el bucket S3 privado.
# ---------------------------------------------------------------------------

# OAC (Origin Access Control)
resource "aws_cloudfront_origin_access_control" "bucket" {
  name                              = "oac-${var.proyecto}-prod-01-cacentral1"
  description                       = "Acceso de CloudFront al bucket estatico"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "bucket" {
  enabled = true
  comment = "cdn-${var.proyecto}-prod-01-cacentral1"

  origin { //donde va a buscar los objetos, el bucket S3 privado
    domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id                = "s3-bucket"
    origin_access_control_id = aws_cloudfront_origin_access_control.bucket.id
  }

  default_cache_behavior { //como se comporta la distribucion al recibir peticiones
    target_origin_id       = "s3-bucket"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Para usar un dominio propio haria falta un certificado ACM emitido en us-east-1.
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "cdn-${var.proyecto}-prod-01-cacentral1" }
}
