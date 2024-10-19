replicaCount: 2
revisionHistoryLimit: 10
image:
  repository: public.ecr.aws/eks/aws-load-balancer-controller
  tag: v2.7.0
  pullPolicy: IfNotPresent
autoscaling:
  enabled: false
serviceAccount:
  create: false
  annotations: {}
  name: "${service_account_name}"

rbac:
  # Specifies whether rbac resources should be created
  create: true

# Time period for the controller pod to do a graceful shutdown
terminationGracePeriodSeconds: 10

clusterName: "${clusterName}"

cluster:
  dnsDomain: ${domain_filter}

ingressClass: alb

region: ${aws_zone}

vpcId: ${vpcId}
