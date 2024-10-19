variable "region" {
  default = "us-east-1"
}

# Fetch EKS cluster details
data "aws_eks_cluster" "control_plane_cluster" {
  name = "${var.env}-${var.control_plane_cluster.name}"
}

data "aws_eks_cluster" "workload_clusters" {
  for_each = var.workload-clusters
  name     = "${var.env}-${each.key}"
}

# Capture OIDC Issuer URL from control plane cluster
locals {
  control_plane_oidc_issuer_url = data.aws_eks_cluster.control_plane_cluster.identity[0].oidc[0].issuer
}

# Fetch the existing OIDC provider for the control plane cluster
data "aws_iam_openid_connect_provider" "control_plane_oidc_provider" {
  url = data.aws_eks_cluster.control_plane_cluster.identity[0].oidc[0].issuer
}


# Capture OIDC Issuer URLs for workload clusters and fetch thumbprints dynamically
locals {
  workload_oidc_issuer_urls = {
    for cluster_name, cluster_data in data.aws_eks_cluster.workload_clusters : cluster_name => cluster_data.identity[0].oidc[0].issuer
  }
}

# Fetch the existing OIDC providers for each workload cluster
data "aws_iam_openid_connect_provider" "workload_oidc_providers" {
  for_each = data.aws_eks_cluster.workload_clusters
  url = each.value.identity[0].oidc[0].issuer
}


# Define the IRSA-required addons for the control plane cluster
locals {
  control_plane_irsa_addons = [
    for blueprint_name in var.control_plane_cluster.addons.list : [
      for addon in try(var.blueprints[blueprint_name].addons, []) : addon
      if contains(var.IRSA, addon)  # Only include addons that are in the IRSA list
    ]
  ]
  # Flatten to ensure we have a simple list of addons
  control_plane_irsa_addons_flat = flatten(local.control_plane_irsa_addons)
}

locals {
  # Extract the OIDC id (the part after /id/) for control plane
  control_plane_oidc_id = replace(data.aws_eks_cluster.control_plane_cluster.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")

  # Extract the OIDC id for workload clusters
  workload_oidc_ids = {
    for cluster_name, cluster_data in data.aws_eks_cluster.workload_clusters : cluster_name => replace(cluster_data.identity[0].oidc[0].issuer, "https://oidc.eks.${var.region}.amazonaws.com/id/", "")
  }
}

# resource "aws_iam_role" "control_plane_irsa_role" {
#   for_each = {
#     for addon in local.control_plane_irsa_addons_flat : "${var.control_plane_cluster.name}-${addon}" => addon
#   }
#
#   name = "${var.env}-${each.key}-irsa-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Federated = data.aws_iam_openid_connect_provider.control_plane_oidc_provider.arn
#       }
#       Action = "sts:AssumeRoleWithWebIdentity"
#       Condition = {
#         StringEquals = {
#           "oidc.eks.${var.region}.amazonaws.com/id/${local.control_plane_oidc_id}:sub" = "system:serviceaccount:${each.key}:${each.key}-sa"
#         }
#       }
#     }]
#   })
# }

resource "aws_iam_role" "control_plane_irsa_role" {
  for_each = {
    for addon in local.control_plane_irsa_addons_flat :
    "${var.control_plane_cluster.name}-${addon}" => {
      cluster_name = var.control_plane_cluster.name,
      addon        = addon
    }
  }

  name = "${var.env}-${each.value.cluster_name}-${each.value.addon}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.control_plane_oidc_provider.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.${var.region}.amazonaws.com/id/${local.control_plane_oidc_id}:sub" = "system:serviceaccount:${each.value.addon}:${each.value.addon}-sa"
        }
      }
    }]
  })
}


# Attach policies for control plane IRSA roles from policy files
resource "aws_iam_role_policy" "control_plane_irsa_policy" {
  for_each = aws_iam_role.control_plane_irsa_role

  name   = "${var.env}-${each.key}-control-plane-policy"
  role   = aws_iam_role.control_plane_irsa_role[each.key].id
  policy = file("${path.module}/policies/${var.env}-${each.key}.json")  # Load policy from file
}

locals {
  # Define the IRSA-required addons for the workload clusters
  workload_irsa_addons = flatten([
    for cluster_name, cluster in var.workload-clusters : [
      for blueprint_name in cluster.addons.list : [
        for addon in try(var.blueprints[blueprint_name].addons, []) : {
          cluster_name = cluster_name
          addon        = addon
        }
        if contains(var.IRSA, addon)  # Only include addons that are in the IRSA list
      ]
    ]
  ])
}

# locals {
#   # Flatten the structure to include cluster_name and addon
#   flattened_workload_irsa_addons = flatten([
#     for cluster_name, cluster_addons in local.workload_irsa_addons : [
#       for addon in cluster_addons : {
#         cluster_name = "${var.env}-${cluster_name}"
#         addon        = addon
#       }
#     ]
#   ])
# }

# Create IAM Role for IRSA in each workload cluster dynamically, including cluster name in the role
resource "aws_iam_role" "workload_irsa_role" {
  for_each = {
    for entry in local.workload_irsa_addons : "${entry.cluster_name}-${entry.addon}" => entry
  }

  name = "${var.env}-${each.value.cluster_name}-${each.value.addon}-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.workload_oidc_providers[each.value.cluster_name].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "oidc.eks.us-east-1.amazonaws.com/id/94EBCBD9636EB04D5322FD9CD1D9F4C9:aud": "sts.amazonaws.com",
          "oidc.eks.${var.region}.amazonaws.com/id/${local.workload_oidc_ids[each.value.cluster_name]}:sub" = "system:serviceaccount:${each.value.addon}:${each.value.addon}-sa"
        }
      }
    }]
  })
}


# Attach policies for workload IRSA roles from policy files
resource "aws_iam_role_policy" "workload_irsa_policy" {
  for_each = {
    for entry in local.workload_irsa_addons : "${entry.cluster_name}-${entry.addon}" => entry
  }

  name   = "${var.env}-${each.value.cluster_name}-${each.value.addon}-policy"
  role   = aws_iam_role.workload_irsa_role[each.key].id

  # Assuming policy files are stored in a folder structure by addon name
  policy = file("${path.module}/policies/${var.env}-${each.value.cluster_name}-${each.value.addon}.json")
}
