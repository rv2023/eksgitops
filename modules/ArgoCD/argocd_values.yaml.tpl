controller:
  serviceAccount:
    create: true
    name: argocd-application-controller
    annotations:
        eks.amazonaws.com/role-arn: ${irsa_role_arn}
    labels: {}
    automountServiceAccountToken: true

logging:
    # -- Set the global logging format. Either: `text` or `json`
    format: text
    # -- Set the global logging level. One of: `debug`, `info`, `warn` or `error`
    level: debug

server:
  extraArgs:
    - --insecure
  serviceAccount:
    create: true
    name: argocd-server
    annotations:
        eks.amazonaws.com/role-arn: ${irsa_role_arn}
    labels: {}
    automountServiceAccountToken: true

configs:
  params:
    server.insecure: true

extraObjects:
  - apiVersion: v1
    kind: Service
    metadata:
      name: argo-svc-ingress
      annotations:
        external-dns.alpha.kubernetes.io/hostname: ${hostname}
        service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${ssl_cert_arn}"
        service.beta.kubernetes.io/aws-load-balancer-internal: "false"
        service.beta.kubernetes.io/aws-load-balancer-subnets: management-public-2, management-public-1
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "http"
        #service.beta.kubernetes.io/aws-load-balancer-security-groups: "sg-087ab071cd22d4873"
    spec:
      type: LoadBalancer
      ports:
      - port: 443
        name: https
        targetPort: 8080
        protocol: TCP
      selector:
        app.kubernetes.io/instance: argo-cd
        app.kubernetes.io/name: argocd-server