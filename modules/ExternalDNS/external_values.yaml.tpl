domainFilters:
  - "${domain_filter}"

provider: aws

aws:
  zoneType: "${aws_zone_type}"

rbac:
  create: true

serviceAccount:
  create: false
  name: "external-dns-sa"