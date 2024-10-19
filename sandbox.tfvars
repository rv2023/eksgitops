vpc_name = "my-vpc"
vpc_cidr = "10.0.0.0/16"
env = "sandbox"
dns_hosts = true
dns_support = true
azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

eks_vpc = {
  management = {
    public_subnets = [
      { name = "management-public-1", cidr = "10.0.0.0/24", tags = {"Production" = "true", "EKS" = "yes"} },
      { name = "management-public-2", cidr = "10.0.1.0/24", tags = {"Production" = "true", "EKS" = "yes"} },
      { name = "management-public-3", cidr = "10.0.2.0/24", tags = {"Production" = "true", "EKS" = "yes"} },
    ]
     private_subnets = [
       { name = "management-private-1", cidr = "10.0.16.0/28", tags = {"Production" = "true", "EKS" = "yes"} },
       { name = "management-private-2", cidr = "10.0.16.16/28", tags = {"Production" = "true", "EKS" = "yes"} },
       { name = "management-private-3", cidr = "10.0.16.32/28", tags = {"Production" = "true", "EKS" = "yes"} },
     ]
  }
}

gitrepo = {
  name = "blue-prints-repo"
  repo = "https://github.com/rv2023/BluePrints.git"
  sshkey = ""
  path = "ApplicationSets"
}

IRSA = ["velero"]

blueprints = {
  CommonBluePrints = {
    addons  = ["externaldns","crowdstrke", "velero"]
  }
  ExpermentalBluePrints = {
    addons  = ["velero", "ack-iam-controller"]
  }
  WorkloadBluePrints = {
    addons  = ["albcontroller"]
  }
  ManagementBluePrints = {
    addons  = ["snow-informer"]
  }
}

control_plane_cluster = {
  name = "control-plane-cluster-01"
  albcontroller = {
    enable = false
    domain_filter = "arna.cloud"
    aws_zone = "us-east-1"
  }
  externaldns = {
    enable = true
    domain_filter = "arna.cloud"
    aws_zone_type = "public"
  }
  argocd = {
    enable = true
    hostname = "argocd.arna.cloud"
    certificate = "arn:aws:acm:us-east-1:073053153137:certificate/d1d1b144-cd54-4a43-8c02-55586b0bcb95"
    version = "7.6.1"
  }
  addons = {
    version = "main"
    list = ["CommonBluePrints"]
  }
  subnets = ["management-public-1", "management-public-2", "management-private-1", "management-private-2"]
  tags = {"Production" = "true", "ControlPlane" = "yes"}
  nodeGroups = {
    nodeGroup-01 = {
      instancetype = "t3.large"
      minCount     = 2
      desiredCount = 2
      maxCount     = 4
      tags         = {"Production" = "true", "EKS" = "yes"}
      subnets      = ["management-public-1", "management-public-2"]
    }
  }
}

workload-clusters = {
  workload-cluster-01 = {
    addons = {
      version = "alpha"
      list = ["ExpermentalBluePrints"]
    }
    subnets = ["management-public-1", "management-public-2", "management-private-1", "management-private-2"]
    tags = {"Production" = "true", "EKS" = "yes"}
    nodeGroups = {
      nodeGroup-01 = {
        instancetype = "t3.medium"
        minCount     = 1
        desiredCount = 1
        maxCount     = 2
        tags         = {"Production" = "true", "EKS" = "yes"}
        subnets      = ["management-public-1", "management-public-2"]
      }
      nodeGroup-02 = {
        instancetype = "t3.medium"
        minCount     = 1
        desiredCount = 1
        maxCount     = 2
        tags         = {"Production" = "true", "EKS" = "yes"}
        subnets      = ["management-public-1", "management-public-2"]
      }
    }
  }
  workload-cluster-02 = {
    addons = {
      version = "beta"
      list = [ "WorkloadBluePrints" ]
    }
    subnets = ["management-public-1", "management-public-2", "management-private-1", "management-private-2"]
    tags = {"Production" = "true", "EKS" = "yes"}
    nodeGroups = {
      nodeGroup-01 = {
        instancetype = "t3.medium"
        minCount     = 1
        desiredCount = 1
        maxCount     = 2
        tags         = {"Production" = "true", "EKS" = "yes"}
        subnets      = ["management-public-1", "management-public-2"]
      }
      nodeGroup-02 = {
        instancetype = "t3.medium"
        minCount     = 1
        desiredCount = 1
        maxCount     = 2
        tags         = {"Production" = "true", "EKS" = "yes"}
        subnets      = ["management-public-1", "management-public-2"]
      }
    }
  }
}