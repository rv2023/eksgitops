# Assuming you pass the IRSA list as a variable
variable "IRSA" {
  type        = list(string)
  description = "List of addons that require IRSA"
}

variable "env" {
  description = "env"
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

variable "blueprints" {
  type = map(object({
    addons  = list(string)
  }))
}