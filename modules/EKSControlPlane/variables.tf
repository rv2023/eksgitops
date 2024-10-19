variable "vpc_name" {
  type        = string
  description = "Name of the VPC where the clusters are created"
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
      domain_filter = string
      aws_zone_type = string
    })
    albcontroller = object({
      domain_filter = string
      aws_zone = string
    })
    argocd = object({
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