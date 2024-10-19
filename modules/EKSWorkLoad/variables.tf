variable "vpc_name" {
  type        = string
  description = "Name of the VPC where the clusters are created"
}

variable "env" {
  description = "env"
  type        = string
}

variable "vpc-id" {
  description = "vpc-id"
  type        = string
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