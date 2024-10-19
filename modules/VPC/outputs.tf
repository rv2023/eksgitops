# output "public_subnets" {
#   value = [for subnet in aws_subnet.public_subnets: subnet.id]
# }
#
# output "private_subnets" {
#   value = [for subnet in aws_subnet.private_subnets: subnet.id]
# }
#
# output "public_route_table_associations" {
#   value = [for assoc in aws_route_table_association.public_route_table_association: assoc.id]
# }
#
# output "private_route_table_associations" {
#   value = [for assoc in aws_route_table_association.private_route_table_association: assoc.id]
# }
#
# output "public_route_table_id" {
#   value = aws_route_table.public_route_table.id
# }
#
# output "private_route_table_id" {
#   value = aws_route_table.private_route_table.id
# }