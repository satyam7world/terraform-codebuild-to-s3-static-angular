resource "aws_codecommit_repository" "emi_repo" {
  repository_name = "emi-calculator-repo"
  default_branch = "master"
  description = "Emi Calculator is a emi calculator built on angular"
}