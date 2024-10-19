variable "env" {
  description = "Name of the VPC"
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
    addons = object({
      version = string  # The version or branch to use for the addons
      list    = list(string)  # A list of blueprint names (e.g., ManagementBluePrints, CommonBluePrints)
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

variable "workload-clusters" {
  type = map(object({
    addons = object({
      version = string  # The version or branch to use for the addons
      list    = list(string)  # A list of blueprint names (e.g., ManagementBluePrints, CommonBluePrints)
    })
    subnets = list(string)
    tags    = map(string)
    nodeGroups = map(object({
      instancetype = string
      minCount     = number
      desiredCount = number
      maxCount     = number
      tags         = map(string)
      subnets      = list(string)
    }))
  }))
  description = "Map of workload clusters with their node group configurations"
}

# Define the git repository details
variable "gitrepo" {
  type = object({
    name = string
    repo   = string
    sshkey = string
    path = string
  })
  description = "Git repository details including repo URL and SSH key"
}

variable "blueprints" {
  type = map(object({
    #gitrepo = string
    addons  = list(string)
  }))
}

# variable "blueprints" {
#   type = object({
#     gitrepo = string
#     types = map(object({
#       addons = list(string)
#     }))
#   })
#   description = "Blueprints object containing gitrepo and a map of blueprint types with their respective addons"
# }