variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "env" {
  description = "env"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "dns_hosts" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
  default     = []
}

variable "eks_vpc" {
  description = "Map of workload clusters with their subnets"
  type = map(object({
    public_subnets = list(object({
      name = string
      cidr = string
      tags = map(string)
    }))
    private_subnets = list(object({
      name = string
      cidr = string
      tags = map(string)
    }))
  }))
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
    addons  = list(string)
  }))
}

# Assuming you pass the IRSA list as a variable
variable "IRSA" {
  type        = list(string)
  description = "List of addons that require IRSA"
}

# variable "blueprints" {
#   type = object({
#     gitrepo = string
#     types = map(object({
#       addons = list(string)
#     }))
#   })
#   description = "Blueprints object containing a git repository URL and a map of blueprint types with their respective addons"
# }