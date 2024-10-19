variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "env" {
  description = "Name of the VPC"
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
