module "VPC" {
  source = "./modules/VPC"
  azs = var.azs
  dns_hosts             = var.dns_hosts
  dns_support           = var.dns_support
  eks_vpc     = var.eks_vpc
  vpc_cidr = var.vpc_cidr
  vpc_name = var.vpc_name
  env = var.env
}

# locals {
#   deploy_alb_controller = contains(keys(var.control_plane_cluster), "albcontroller")
#   deploy_externaldns = contains(keys(var.control_plane_cluster), "externaldns")
#   deploy_argocd = contains(keys(var.control_plane_cluster), "argocd")
# }

module "EKSWorkLoad" {
  source = "./modules/EKSWorkLoad"
  vpc_name    = var.vpc_name
  workload-clusters    = var.workload-clusters
  vpc-id = module.VPC.vpc_id
  depends_on = [
    module.EKSControlPlane
  ]
  env = var.env
}

module "EKSControlPlane" {
  source = "./modules/EKSControlPlane"
  vpc_name  = var.vpc_name
  env = var.env
  control_plane_cluster  = var.control_plane_cluster
  depends_on = [
    module.VPC
  ]
}

module "ALB" {
  source = "./modules/ALB"
  count = var.control_plane_cluster.albcontroller.enable ? 1 : 0
  #count  = local.deploy_alb_controller ? 1 : 0
  control_plane_cluster  = var.control_plane_cluster
  oidc_issuer_arn = module.EKSControlPlane.oidc_issuer_arn
  oidc_issuer_url = module.EKSControlPlane.oidc_issuer_url
  vpc-id = module.VPC.vpc_id
  env = var.env
  depends_on = [
    module.EKSControlPlane
  ]
}

module "ExternalDNS" {
  source = "./modules/ExternalDNS"
  count = var.control_plane_cluster.externaldns.enable ? 1 : 0
  #count  = local.deploy_externaldns ? 1 : 0
  control_plane_cluster  = var.control_plane_cluster
  oidc_issuer_arn = module.EKSControlPlane.oidc_issuer_arn
  oidc_issuer_url = module.EKSControlPlane.oidc_issuer_url
  env = var.env
  depends_on = [
    module.ALB, module.EKSControlPlane
  ]
}

module "ArgoCD" {
  source = "./modules/ArgoCD"
  count = var.control_plane_cluster.argocd.enable ? 1 : 0
  env = var.env
  control_plane_cluster = var.control_plane_cluster
  workload-clusters = var.workload-clusters
  gitrepo = var.gitrepo
  oidc_issuer_arn = module.EKSControlPlane.oidc_issuer_arn
  oidc_issuer_url = module.EKSControlPlane.oidc_issuer_url
  blueprints = var.blueprints
  depends_on = [
    module.ExternalDNS, module.EKSControlPlane, module.EKSWorkLoad, module.IRSA
  ]
}

module "IRSA" {
  source = "./modules/IRSA"
  IRSA = var.IRSA
  blueprints = var.blueprints
  control_plane_cluster = var.control_plane_cluster
  env    = var.env
  workload-clusters = var.workload-clusters
  depends_on = [
    module.EKSWorkLoad, module.EKSControlPlane, module.ALB
  ]
}