variable "AWS_LAMBDA_NAME" {
  type        = string
  description = "Name of the lambda."
}

variable "AWS_REGION" {
  type        = string
  description = "AWS region."
}

variable "AUTH" {
  type        = string
  description = "The string used to authenticate the lambda."
  sensitive   = true
}

variable "SECURITY_GROUP_IDS" {
  type        = list(string)
  description = "The IDs of the security groups to associate with the lambda."
}

variable "SUBNET_IDS" {
  type        = list(string)
  description = "The IDs of the subnets to associate with the lambda."
}


data "aws_iam_policy" "AWSLambdaVPCAccessExecutionRole" {
  arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_caller_identity" "current" {}

data "aws_ecr_repository" "ecr_repo" {
  name = var.AWS_LAMBDA_NAME
}

data "aws_ecr_image" "repo_image" {
  repository_name = data.aws_ecr_repository.ecr_repo.name
  image_tag       = "latest"
}
