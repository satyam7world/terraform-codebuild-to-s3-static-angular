# Step 1 - Clone the git repo to this local computer
resource "null_resource" "emi_git_clone" {
  provisioner "local-exec" {
    command = "git clone https://github.com/satyam7world/emi-calculator-angular.git"
  }
}

resource "aws_s3_bucket" "emi_bucket" {
  bucket = "emi-calculator-tf"
  tags = {
    Name : "Emi Calculator Bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.emi_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_public_access" {
  bucket                  = aws_s3_bucket.emi_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [aws_s3_bucket.emi_bucket, aws_s3_bucket_public_access_block.bucket_public_access]
  bucket     = aws_s3_bucket.emi_bucket.id
  acl        = "public-read"
}

resource "aws_s3_bucket_object" "copy_emi_angular" {
  bucket   = aws_s3_bucket.emi_bucket.id
  for_each = fileset("./emi-calculator-angular/", "**/*")
  key      = each.value
  source   = "./emi-calculator-angular/${each.value}"
  etag     = filemd5("./emi-calculator-angular/${each.value}")
}

# resource "aws_iam_role" "codebuild_role" {
#   assume_role_policy = ""
# }


resource "aws_codebuild_project" "emi_cd_builder" {
  name          = "emi-cd-builder"
  service_role  = var.cloudbuild_service_role
  build_timeout = 5
  source {
    type      = "S3"
    buildspec = <<EOH
version: 0.2

phases:
  build:
    commands:
       - npm install
       - npm run build
artifacts:
  files:
    - 'dist/pariyojan88/*'
  discard-paths: yes
EOH
  }
  artifacts {
    type                = "S3"
    encryption_disabled = true
    path                = "/"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "docker.io/node:16.10.0-buster"
    type         = "LINUX_CONTAINER"
    registry_credential {
      credential          = var.docker_cred_secret_manager_arn
      credential_provider = "SECRETS_MANAGER"
    }
  }
}

# resource "aws_s3_bucket_policy" "bucket_policy" {
#   bucket = aws_s3_bucket.emi_bucket.id
#   policy = ""
# }

# resource "aws_codecommit_repository" "emi_repo" {
#   repository_name = "emi-calculator-repo"
#   default_branch = "master"
#   description = "Emi Calculator is a emi calculator built on angular"
#  }