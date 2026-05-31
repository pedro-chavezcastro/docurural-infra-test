################################################################################
# DocuRural — Módulo IAM — outputs.tf
################################################################################

output "role_name" {
  description = "Nombre del IAM Role del EC2"
  value       = aws_iam_role.ec2_role.name
}

output "role_arn" {
  description = "ARN del IAM Role del EC2"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "Nombre del instance profile para asignar al EC2"
  value       = aws_iam_instance_profile.ec2_profile.name
}
