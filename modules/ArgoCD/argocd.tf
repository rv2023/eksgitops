resource "aws_iam_role" "argocd-role" {
  name = "${var.env}-${var.control_plane_cluster.name}-argocd-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          Federated = var.oidc_issuer_arn
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = ["system:serviceaccount:argocd:argocd-application-controller", "system:serviceaccount:argocd:argocd-server"],
            "${replace(var.oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  values = [
    templatefile("${path.module}/argocd_values.yaml.tpl", {
      hostname     = var.control_plane_cluster.argocd.hostname
      ssl_cert_arn = var.control_plane_cluster.argocd.certificate
      irsa_role_arn = aws_iam_role.argocd-role.arn
    })
  ]
  version = var.control_plane_cluster.argocd.version
}

# Data source for EKS cluster details
data "aws_eks_cluster" "eks_data" {
  for_each = var.workload-clusters
  name     = "${var.env}-${each.key}"
}

############################################
# Data source for EKS cluster authentication
data "aws_eks_cluster_auth" "eks_auth" {
  for_each = var.workload-clusters
  name     = "${var.env}-${each.key}"
}

# Data source for EKS cluster details
data "aws_eks_cluster" "controlplane_eks_data" {
  name     = "${var.env}-${var.control_plane_cluster.name}"
}

# Data source for EKS cluster authentication
data "aws_eks_cluster_auth" "controlplane_eks_auth" {
  name     = "${var.env}-${var.control_plane_cluster.name}"
}

################################################
locals {
  workload_cluster_configs = {
    for cluster_name, cluster_config in var.workload-clusters :
    cluster_name => {
      name                   = cluster_name
      endpoint               = data.aws_eks_cluster.eks_data[cluster_name].endpoint
      cluster_ca_certificate = data.aws_eks_cluster.eks_data[cluster_name].certificate_authority[0].data
      token                  = data.aws_eks_cluster_auth.eks_auth[cluster_name].token
      arn                    = data.aws_eks_cluster.eks_data[cluster_name].arn
      version                = cluster_config.addons.version
    }
  }
}


locals {
  control_plane_blueprints = var.control_plane_cluster.addons.list
  # Collect the list of blueprint names from the control plane cluster's addon list
  # Dynamically create the addon labels from the blueprints block based on control_plane_blueprints
  control_plane_addon_labels = merge(
    {
      "argocd.argoproj.io/secret-type"  = "cluster",
      "argocd.argoproj.io/cluster-name" = "${var.env}-${var.control_plane_cluster.name}"
    },
    # Flatten to ensure merge gets a flat list of maps for each addon
    merge(flatten([
      for blueprint in local.control_plane_blueprints : [
        for addon in try(var.blueprints[blueprint].addons, []) : {
          "addons/${addon}" = "true"
        }
      ]
    ])...)
  )
}



resource "kubernetes_secret" "argocd-clusters" {
  metadata {
    name      = "${var.env}-${var.control_plane_cluster.name}"
    namespace = "argocd"
    labels = local.control_plane_addon_labels  # Use generated labels
    annotations = {
      env = var.env,
      aws_cluster_name = var.control_plane_cluster.name,
      addons_git_repo = var.gitrepo.name,
      addons_git_repo_version = var.control_plane_cluster.addons.version,
      argocd_project_name = "multi-cluster-hub-spoke-project",
      addons_git_repo_url = var.gitrepo.repo
    }
  }
  data = {
    "name"   = "${var.env}-${var.control_plane_cluster.name}",
    "server" = "https://kubernetes.default.svc"
    "config" = jsonencode({
      "tlsClientConfig" = {
        "insecure" = false
      }
    })
  }
  type = "Opaque"
  depends_on = [helm_release.argocd]
}

## ControlPlane role trusts argocd
resource "aws_iam_policy" "argocd_controller_policy" {
  name        = "${var.env}-${var.control_plane_cluster.name}-ArgoCD-Policy"
  description = "Policy for ExternalDNS to manage DNS records in Route 53"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}



resource "aws_iam_role_policy_attachment" "argocd_controller_policy_attach" {
  policy_arn = aws_iam_policy.argocd_controller_policy.arn
  role     = aws_iam_role.argocd-role.name
}

##WorkerNodes Access entries trust controlplane

resource "aws_iam_role" "worker-argocd-role" {
  for_each = local.workload_cluster_configs
  name = "${var.env}-${each.key}-access-list-argocd-role"
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          AWS = aws_iam_role.argocd-role.arn
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "worker_argocd_controller_policy_attach" {
  for_each = local.workload_cluster_configs
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role     = aws_iam_role.worker-argocd-role[each.key].name
}

resource "aws_eks_access_entry" "argocd_access_entry" {
  for_each = local.workload_cluster_configs
  cluster_name      = "${var.env}-${each.key}"
  principal_arn     = aws_iam_role.worker-argocd-role[each.key].arn
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "argocd_access_entry_policy" {
  for_each      = local.workload_cluster_configs
  cluster_name  = "${var.env}-${each.key}"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn     = aws_iam_role.worker-argocd-role[each.key].arn
  access_scope {
    type       = "cluster"
  }
}

locals {
  # Collect the list of blueprint names from the workload clusters
  workload_blueprints = flatten([
    for cluster_name, cluster in var.workload-clusters : [
      for blueprint_name in cluster.addons.list : {
        cluster_name    = cluster_name
        blueprint_name  = blueprint_name
      }
    ]
  ])

  workload_cluster_labels = {
    for cluster_name, cluster in var.workload-clusters : cluster_name => merge(
      {
        "argocd.argoproj.io/secret-type"  = "cluster",
        "argocd.argoproj.io/cluster-name" = "${var.env}-${cluster_name}"  # Use the actual cluster name here
      },
      # Merge the addon labels for each blueprint in the cluster
      merge(flatten([
        for blueprint in cluster.addons.list : [
          for addon in try(var.blueprints[blueprint].addons, []) : {
            "addons/${addon}" = "true"
          }
        ]
      ])...)
    )
  }
}

# Create a Kubernetes secret for each workload cluster using dynamic labels
resource "kubernetes_secret" "argocd_worker_clusters" {
  for_each = local.workload_cluster_configs

  metadata {
    name      = "${var.env}-${each.key}"
    namespace = "argocd"
    labels    = local.workload_cluster_labels[each.key]  # Use generated labels for each cluster
    annotations = {
      env = var.env,
      aws_cluster_name = "${var.env}-${each.key}",
      addons_git_repo = var.gitrepo.name,
      addons_git_repo_version = each.value.version,
      argocd_project_name = "multi-cluster-hub-spoke-project"
      addons_git_repo_url = var.gitrepo.repo
    }
  }
    data = {
      "name"   = "${var.env}-${each.value.name}",
      "server" = each.value.endpoint,
      "config" = jsonencode({
        "awsAuthConfig" = {
          "clusterName" = "${var.env}-${each.value.name}",
          "roleARN"     =  aws_iam_role.worker-argocd-role[each.key].arn
        },
        "tlsClientConfig" = {
          "insecure" = false,
          "caData"   = each.value.cluster_ca_certificate
        }
      })
    }
    type = "Opaque"
    depends_on = [helm_release.argocd]
}



# Conditionally create the SSH secret supported git repo if sshkey is provided
resource "kubernetes_secret" "argocd_repo_private" {
  count = var.gitrepo.sshkey != "" ? 1 : 0  # Only create secret if SSH key is provided
  metadata {
    name      = var.gitrepo.name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  data = {
    "type": "git"
    "url": var.gitrepo.repo
    "sshPrivateKey" = base64encode(var.gitrepo.sshkey)
    "project" = "multi-cluster-hub-spoke-project"
  }
  type = "Opaque"
}

# Conditionally create the SSH secret supported git repo if sshkey is provided
resource "kubernetes_secret" "argocd_repo_public" {
  count = var.gitrepo.sshkey != "" ? 0 : 1  # Only create secret for publuc repo
  metadata {
    name      = var.gitrepo.name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  data = {
    "type": "git"
    "url": var.gitrepo.repo
    "project" = "multi-cluster-hub-spoke-project"
  }
  type = "Opaque"
}


resource "kubernetes_manifest" "argocd_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "multi-cluster-hub-spoke-project"
      namespace = "argocd"
    }
    spec = {
      description = "Project to manage clusters and addons"
      destinations = [{
        namespace = "*"
        server    = "*"
      }]
      sourceRepos = [var.gitrepo.repo]
      clusterResourceWhitelist = [{
        group = "*"
        kind  = "*"
      }]
    }
  }
  depends_on = [helm_release.argocd, var.control_plane_cluster ]
}

# Create the ArgoCD "App of Apps" that points to the Git repository containing the other applications
# Loop through each workload cluster and create a separate App of Apps for each
resource "kubernetes_manifest" "controlplane_app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.env}-addons"
      namespace = "argocd"
    }
    spec = {
      project = "multi-cluster-hub-spoke-project"  # Use the previously created project
      source = {
        repoURL        = var.gitrepo.repo  # Use the Git repository URL
        targetRevision = var.control_plane_cluster.addons.version  # Use the version from the tfvars for each cluster
        path           = var.gitrepo.path  # Path for each cluster's app definition in Git
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune     = true
          selfHeal  = true
        }
      }
    }
  }
  depends_on = [helm_release.argocd, kubernetes_manifest.argocd_project]
}

# resource "kubernetes_manifest" "workload_app_of_apps" {
#   for_each = var.workload-clusters
#
#   manifest = {
#     apiVersion = "argoproj.io/v1alpha1"
#     kind       = "Application"
#     metadata = {
#       name      = "${var.env}-${each.key}-addons"
#       namespace = "argocd"
#     }
#     spec = {
#       project = "multi-cluster-hub-spoke-project"  # Use the previously created project
#       source = {
#         repoURL        = var.gitrepo.repo  # Use the Git repository URL
#         targetRevision = each.value.addons.version  # Use the version from the tfvars for each cluster
#         path           = var.gitrepo.path  # Path for each cluster's app definition in Git
#       }
#       destination = {
#         server    = "https://kubernetes.default.svc"
#         namespace = "argocd"
#       }
#       syncPolicy = {
#         automated = {
#           prune     = true
#           selfHeal  = true
#         }
#       }
#     }
#   }
#   depends_on = [helm_release.argocd, kubernetes_manifest.argocd_project]
# }