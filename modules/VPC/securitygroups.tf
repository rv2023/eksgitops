# resource "aws_security_group" "opsman-Group" {
#   name        = "pcf-ops-manager-security-group"
#   description = "Allow inbound and outbound traffic in opsman"
#   vpc_id      = "${aws_vpc.pcf-cluster-vpc.id}"
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     #self 		= true
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     #self        = true
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     #self	    = true
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 6868
#     to_port     = 6868
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc-cidr]
#
#   }
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 25555
#     to_port     = 25555
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc-cidr]
#
#   }
#
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "pcf-ops-manager-security-group"
#     Env = var.env
#   }
#   depends_on = [aws_subnet.public, aws_subnet.pas, aws_subnet.management, aws_subnet.services, aws_subnet.rds]
#
# }
#
#
# resource "aws_security_group" "vms-Group" {
#   name        = "pcf-vms-security-group"
#   description = "Allow inbound and outbound traffic in opsman"
#   vpc_id      = "${aws_vpc.pcf-cluster-vpc.id}"
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#
#   }
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "pcf-vms-security-group"
#     Env = var.env
#   }
#   depends_on = [aws_subnet.public, aws_subnet.pas, aws_subnet.management, aws_subnet.services, aws_subnet.rds]
#
# }
#
#
# resource "aws_security_group" "elb-web-sg-grp" {
#   name        = "pcf-web-elb-security-group"
#   description = "Allow inbound and outbound traffic in opsman"
#   vpc_id      = "${aws_vpc.pcf-cluster-vpc.id}"
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 4443
#     to_port     = 4443
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#
#   }
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#
#   }
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#
#   }
#
#   #egress {
#   #  from_port   = 0
#   #  to_port     = 0
#   #  protocol    = "-1"
#   #  cidr_blocks = ["0.0.0.0/0"]
#   #}
#
#   tags = {
#     Name = "pcf-web-elb-security-group"
#     Env = var.env
#   }
#   depends_on = [aws_subnet.public, aws_subnet.pas, aws_subnet.management, aws_subnet.services, aws_subnet.rds]
#
# }
#
#
# resource "aws_security_group" "elb-ssh-sg-grp" {
#   name        = "pcf-ssh-elb-security-group"
#   description = "Allow inbound and outbound traffic in opsman"
#   vpc_id      = "${aws_vpc.pcf-cluster-vpc.id}"
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 2222
#     to_port     = 2222
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#
#   }
#
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "pcf-ssh-elb-security-group"
#     Env = var.env
#   }
#   depends_on = [aws_subnet.public, aws_subnet.pas, aws_subnet.management, aws_subnet.services, aws_subnet.rds]
#
# }
#
#
# resource "aws_security_group" "elb-tcp-sg-grp" {
#   name        = "pcf-tcp-elb-security-group"
#   description = "Allow inbound and outbound traffic in opsman"
#   vpc_id      = "${aws_vpc.pcf-cluster-vpc.id}"
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 1024
#     to_port     = 1123
#     protocol    = "TCP"
#     cidr_blocks = ["0.0.0.0/0"]
#
#   }
#
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   tags = {
#     Name = "pcf-tcp-elb-security-group"
#     Env  = var.env
#   }
#   depends_on = [aws_subnet.public, aws_subnet.pas, aws_subnet.management, aws_subnet.services, aws_subnet.rds]
#
# }
#
#
# resource "aws_security_group" "msql-security-group" {
#   name        = "pcf-mysql-security-group"
#   description = "Allow inbound and outbound traffic in opsman"
#   vpc_id      = "${aws_vpc.pcf-cluster-vpc.id}"
#
#   ingress {
#     description = "TLS from VPC"
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "TCP"
#     cidr_blocks = [var.vpc-cidr]
#
#   }
#
#
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = [var.vpc-cidr]
#   }
#
#   tags = {
#     Name = "pcf-mysql-security-group"
#     Env = var.env
#   }
#   depends_on = [aws_subnet.public, aws_subnet.pas, aws_subnet.management, aws_subnet.services, aws_subnet.rds]
#
# }