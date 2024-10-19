variable "env" {
  description = "env"
  type        = string
}

variable "oidc_issuer_url" {
  description = "Map of OIDC issuer URLs for the EKS clusters"
  type        = string
}

variable "oidc_issuer_arn" {
  description = "Map of OIDC issuer URLs for the EKS clusters"
  type        = string
}

# Variable for control plane cluster
variable "control_plane_cluster" {
  type = object({
    name = string
    externaldns = object({
      enable = bool
      domain_filter = string
      aws_zone_type = string
    })
    albcontroller = object({
      enable = bool
      domain_filter = string
      aws_zone = string
    })
    argocd = object({
      enable = bool
      hostname   = string
      certificate = string
      version = string
    })
    subnets = list(string)
    tags = map(string)
    nodeGroups = map(object({
      instancetype = string
      minCount     = number
      desiredCount = number
      maxCount     = number
      tags         = map(string)
      subnets      = list(string)
    }))
  })
  description = "Configuration for the control plane cluster"
}

# variable "workload-clusters" {
#   type = map(object({
#     subnets = list(string)
#     #install_argocd = bool
#     externaldns = object({
#       domain_filter = string
#       aws_zone_type = string
#     })
#     albcontroller = object({
#       domain_filter = string
#       aws_zone = string
#       vpcId = string
#     })
#     argocd = object({
#       hostname   = string
#       certificate = string
#       version = string
#     })
#     tags    = map(string)
#     nodeGroups = map(object({
#       instancetype = string
#       minCount     = number
#       desiredCount = number
#       maxCount     = number
#       tags         = map(string)
#       subnets      = list(string)
#     }))
#   }))
#   description = "Map of workload clusters with their node group configurations"
# }