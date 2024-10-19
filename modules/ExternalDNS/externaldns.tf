resource "kubernetes_namespace" "kube_system" {
  metadata {
    name = "external-dns"
  }
}

resource "aws_iam_policy" "external_dns" {
  name        = "${var.env}-ExternalDNSPolicy"
  description = "Policy for ExternalDNS to manage DNS records in Route 53"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZones",
          "route53:GetHostedZone",
          "route53:ListHostedZonesByName"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "external_dns" {
  name = "${var.env}-external-dns-role-${var.control_plane_cluster.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = var.oidc_issuer_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:external-dns:external-dns-sa"
            "${replace(var.oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns.arn
  #policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
  role     = aws_iam_role.external_dns.name
}


# Kubernetes Service Account
resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns-sa"
    namespace = "external-dns"
    labels = {
      "app.kubernetes.io/name" = "external-dns"
    }
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }
  automount_service_account_token = true
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "external-dns"

  values = [
    templatefile("${path.module}/external_values.yaml.tpl", {
      domain_filter = var.control_plane_cluster.externaldns.domain_filter
      aws_zone_type = var.control_plane_cluster.externaldns.aws_zone_type
      service_account_name = kubernetes_service_account.external_dns.metadata[0].name
    })
  ]
}