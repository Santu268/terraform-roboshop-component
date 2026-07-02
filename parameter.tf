# resource "aws_ssm_parameter" "mysql_passwd" {
#   name  = "/${var.project}/${var.env}/MYSQL_ROOT_PASSWORD"
#   type  = "SecureString"
#   value = var.mysql_passwd
#   overwrite = true
# }