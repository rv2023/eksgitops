# IAM role for EKS clusters
resource "aws_iam_role" "eks_cluster" {
  name = "${var.env}-${var.control_plane_cluster.name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Data source to get subnet IDs from subnet names for control plane cluster
locals {
  control_plane_subnets = distinct(flatten([
    for cng in var.control_plane_cluster.subnets : cng
  ]))
}

# Data source to get subnet IDs from subnet names for node groups
data "aws_subnet" "control_plane_subnets" {
  for_each = toset(local.control_plane_subnets)

  filter {
    name   = "tag:Name"
    values = [each.key]
  }
}

# Map subnet names to IDs for easy access
locals {
  control_plane_subnet_ids_by_name = {
    for subnet_name, subnet in data.aws_subnet.control_plane_subnets :
    subnet_name => subnet.id
  }
}

resource "aws_eks_cluster" "eks" {
  name     = "${var.env}-${var.control_plane_cluster.name}"
  role_arn = aws_iam_role.eks_cluster.arn
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    subnet_ids = [
      for subnet_name in var.control_plane_cluster.subnets :
      local.control_plane_subnet_ids_by_name[subnet_name]
    ]
  }
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  tags = var.control_plane_cluster.tags
  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}


# IAM policy attachment for EKS
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

locals {
  node_groups = flatten([
    for node_group_name, node_group_data in var.control_plane_cluster.nodeGroups: {
      #node_group_name = "${var.env}-${node_group_name}"
      subnets         = node_group_data.subnets
      tags             = node_group_data.tags
      desired_count   = node_group_data.desiredCount
      max_count       = node_group_data.maxCount
      min_count       = node_group_data.minCount
    }
  ])
}

# Data source to get subnet IDs from subnet names for control plane cluster
locals {
  control_plane_nodegroup_subnets = distinct(flatten([
    for ng in var.control_plane_cluster.nodeGroups : ng.subnets
  ]))
}

# Data source to get subnet IDs from subnet names for node groups
data "aws_subnet" "control_plane_nodegroup_subnets" {
  for_each = toset(local.control_plane_nodegroup_subnets)

  filter {
    name   = "tag:Name"
    values = [each.key]
  }
}

# Map subnet names to IDs for easy access
locals {
  control_plane_ng_subnet_ids_by_name = {
    for subnet_name, subnet in data.aws_subnet.control_plane_nodegroup_subnets :
    subnet_name => subnet.id
  }
}


resource "aws_eks_node_group" "control_plane_node_groups" {
  for_each       = var.control_plane_cluster.nodeGroups
  cluster_name   = "${var.env}-${var.control_plane_cluster.name}"
  node_group_name = "${var.env}-${var.control_plane_cluster.name}-${each.key}"
  node_role_arn  = "arn:aws:iam::073053153137:role/myAmazonEKSNodeGroupRole"
  subnet_ids = [
    for subnet_name in each.value.subnets :
    local.control_plane_ng_subnet_ids_by_name[subnet_name]
  ]
  scaling_config {
    desired_size = each.value.desiredCount
    max_size     = each.value.maxCount
    min_size     = each.value.minCount
  }
  instance_types = [each.value.instancetype]
  tags = merge(
    var.control_plane_cluster.tags,
    each.value.tags,
    {
      "Name"       = "${var.env}-${var.control_plane_cluster.name}-${each.key}"
      "Cluster"    = var.control_plane_cluster.name
      "Environment" = var.env
    }
  )
}

# # Capture OIDC Issuer URL
locals {
  eks_oidc_issuer_url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# # Fetch the OIDC provider's thumbprint
data "tls_certificate" "eks_oidc_thumbprint" {
  url = local.eks_oidc_issuer_url
}

# Create IAM OIDC Provider
resource "aws_iam_openid_connect_provider" "eks_oidc_provider" {
  url = replace(local.eks_oidc_issuer_url, "^https://", "")

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [data.tls_certificate.eks_oidc_thumbprint.certificates[0].sha1_fingerprint]

  tags = {
    Name = "${var.control_plane_cluster.name}-oidc-provider"
  }
}

# OIDC Issuer URL
output "oidc_issuer_arn" {
  value       = aws_iam_openid_connect_provider.eks_oidc_provider.arn
  description = "The OIDC issuer ARN for the EKS cluster"
}

# OIDC Issuer URL
output "oidc_issuer_url" {
  value       = aws_iam_openid_connect_provider.eks_oidc_provider.url
  description = "The OIDC issuer URL for the EKS cluster"
}