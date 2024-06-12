
# Step 1 - Clone the git repo to this local computer
resource "null_resource" "emi_git_clone" {
  provisioner "local-exec" {
    command = "git clone https://github.com/satyam7world/emi-calculator-angular.git"
  }
}

# resource "aws_s3_bucket" "emi_bucket" {
#   bucket = "emi-calculator-tf"
# }

# resource "aws_codecommit_repository" "emi_repo" {
#   repository_name = "emi-calculator-repo"
#   default_branch = "master"
#   description = "Emi Calculator is a emi calculator built on angular"
#  }