terraform {
  backend "s3" {
    bucket         = "k8-terraform-bucket"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region  = "us-east-1"
}


data "aws_eks_cluster" "default" {
  name = "${var.env}-${var.control_plane_cluster.name}"
  depends_on = [module.EKSControlPlane, module.VPC]
}

data "aws_eks_cluster_auth" "default" {
  name = "${var.env}-${var.control_plane_cluster.name}"
  depends_on = [module.EKSControlPlane, module.VPC]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "helm" {
  repository_config_path = "${path.module}/.helm/repositories.yaml"
  repository_cache       = "${path.module}/.helm"
  kubernetes {
    host                   = data.aws_eks_cluster.default.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.default.token
  }
}