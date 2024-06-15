variable "docker_cred_secret_manager_arn" {}

# Step 1 - Create S3 Bucket for Static Website Hosting
resource "aws_s3_bucket" "emi_bucket" {
  bucket        = "emi-calculator-tf"
  force_destroy = true
  tags = {
    Name : "Emi Calculator Bucket"
  }
}
# Step 1.x - S3 Bucket Ownership Controls
resource "aws_s3_bucket_ownership_controls" "bucket_ownership" {
  bucket = aws_s3_bucket.emi_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
# Step 1.x - S3 Bucket Enable Public Access
resource "aws_s3_bucket_public_access_block" "bucket_public_access" {
  bucket                  = aws_s3_bucket.emi_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Step 1.x - S3 Bucket ACL for Fine Tune Grant - Grantee Permissions
resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [aws_s3_bucket.emi_bucket, aws_s3_bucket_public_access_block.bucket_public_access]
  bucket     = aws_s3_bucket.emi_bucket.id
  acl        = "public-read"
}

# Step 1.x - S3 Enable Static Hosting
resource "aws_s3_bucket_website_configuration" "bucket_static_website" {
  depends_on = [aws_s3_bucket.emi_bucket]
  bucket     = aws_s3_bucket.emi_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

# Step 1.x - S3 Bucket Make Every Object Public Accessible by Default
resource "aws_s3_bucket_policy" "bucket_public_policy" {
  bucket = aws_s3_bucket.emi_bucket.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "BucketPublicAccessToGetObject",
        "Principal" : "*",
        "Effect" : "Allow",
        "Action" : [
          "s3:GetObject"
        ],
        "Resource" : [
          "${aws_s3_bucket.emi_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Step 2 - Creation of Service Role - This is Trust Policy it defines list of AWS services
# which will be able to use this service role, later we'll add iam_policy in this, it will grant
# access to required services.
resource "aws_iam_role" "codebuild_service_role" {
  name               = "codebuild-service-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "codebuild.amazonaws.com"
            ]
          }
        }
      ]
    }
  )
}

# Step 2.x - Adding iam_policy in service role
resource "aws_iam_role_policy" "role_policy" {
  role   = aws_iam_role.codebuild_service_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "CodeBuildDefaultPolicy",
        "Effect" : "Allow",
        "Action" : [
          "codebuild:*",
          "iam:PassRole"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "CloudWatchLogsAccessPolicy",
        "Effect" : "Allow",
        "Action" : [
          "logs:FilterLogEvents",
          "logs:GetLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "S3AccessPolicy",
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:GetObject",
          "s3:List*",
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ],
        "Resource" : "*"
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# Step 3 - Aws Codebuild - For CI , it will build our angular application using
# `ng build` and will upload to our s3 static website`s bucket
resource "aws_codebuild_project" "emi_cd_builder" {
  name          = "emi-cd-builder"
  service_role  = aws_iam_role.codebuild_service_role.arn
  build_timeout = 5

  source {
    type      = "GITHUB"
    location  = "https://github.com/satyam7world/emi-calculator-angular.git"
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
    location            = aws_s3_bucket.emi_bucket.bucket
    name                = "/"
  }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "docker.io/node:16.10.0-buster"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential {
      credential          = var.docker_cred_secret_manager_arn
      credential_provider = "SECRETS_MANAGER"
    }
  }
}

# Step 4 - Codebuild is created but it's not building anything, so i am invoking it
# with the aws_scheduler_schedule

resource "aws_iam_role" "emi-codebuild-scheduler-invoker-role" {
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "scheduler.amazonaws.com"
          },
          "Action" : "sts:AssumeRole"
          #           "Condition" : {
          #             "StringEquals" : {
          #               "aws:SourceAccount" : "************"
          #             }
          #           }
        }
      ]
    }
  )
}

resource "aws_iam_role_policy" "emi-codebuild-scheduler-invoker-policy" {
  role   = aws_iam_role.codebuild_service_role.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "AllowCodeBuildInvokePermissions",
          "Effect" : "Allow",
          "Action" : "codebuild:Start*",
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "time_offset" "scheduled-build-invoke-time" {
  offset_minutes = 1
}

# variable "string-scheduled" {
#   type    = string
#   default = null
# }

# locals {
#   string-scheduled = substr(time_offset.scheduled-build-invoke-time.base_rfc3339, 0, -2)
# }

resource "aws_scheduler_schedule" "auto-codebuild-invoker" {
  schedule_expression = "at(${substr(time_offset.scheduled-build-invoke-time.base_rfc3339, 0, -2)})"
  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 4
  }
  target {
    arn      = aws_codebuild_project.emi_cd_builder.arn
    role_arn = aws_iam_role.emi-codebuild-scheduler-invoker-role.arn
  }
  schedule_expression_timezone = "Asia/Calcutta"
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