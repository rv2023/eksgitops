data "aws_subnet" "selected" {
  for_each = toset(flatten([for cluster_name, cluster_data in var.workload-clusters : cluster_data.subnets]))

  filter {
    name   = "tag:Name"
    values = [each.value]
  }

  filter {
    name   = "vpc-id"
    values = [var.vpc-id]
  }
}


resource "aws_eks_cluster" "eks" {
  for_each = var.workload-clusters
  name     = "${var.env}-${each.key}"
  role_arn = aws_iam_role.eks_cluster[each.key].arn
  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    subnet_ids = [for subnet in each.value.subnets : data.aws_subnet.selected[subnet].id]
  }
  access_config {
    authentication_mode  = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
  tags = each.value.tags
  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

data "aws_eks_cluster" "eks" {
  for_each = var.workload-clusters
  name = aws_eks_cluster.eks[each.key].name
}

data "tls_certificate" "demo" {
  for_each = var.workload-clusters
  url = aws_eks_cluster.eks[each.key].identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "demo" {
  for_each = var.workload-clusters
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.demo[each.key].certificates[0].sha1_fingerprint]
  url = aws_eks_cluster.eks[each.key].identity[0].oidc[0].issuer
}

output "oidc_issuer_url" {
  value = { for k, v in data.tls_certificate.demo : k => v.url }
}

# IAM role for EKS clusters
resource "aws_iam_role" "eks_cluster" {
  for_each = var.workload-clusters
  name = "${var.env}-${each.key}-eks-workload-cluster-role"

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

# IAM policy attachment for EKS
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each = var.workload-clusters
  role       = aws_iam_role.eks_cluster[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

locals {
  # Create a flattened map of node groups from all clusters
  node_groups = flatten([
    for cluster_name, cluster_data in var.workload-clusters : [
      for node_group_name, node_group_data in cluster_data.nodeGroups : {
        cluster_name    = cluster_name
        node_group_name = "${var.env}-${node_group_name}"
        subnets         = node_group_data.subnets
        tags             = node_group_data.tags
        desired_count   = node_group_data.desiredCount
        max_count       = node_group_data.maxCount
        min_count       = node_group_data.minCount
      }
    ]
  ])
}

resource "aws_eks_node_group" "node_group" {
  for_each = { for ng in local.node_groups : "${ng.cluster_name}-${ng.node_group_name}" => ng }

  cluster_name    = aws_eks_cluster.eks[each.value.cluster_name].id
  node_group_name = each.value.node_group_name
  node_role_arn = "arn:aws:iam::073053153137:role/myAmazonEKSNodeGroupRole"

  subnet_ids = [
    for subnet_name in each.value.subnets : data.aws_subnet.selected[subnet_name].id
  ]

  scaling_config {
    desired_size = each.value.desired_count
    max_size     = each.value.max_count
    min_size     = each.value.min_count
  }

  tags = each.value.tags

}
