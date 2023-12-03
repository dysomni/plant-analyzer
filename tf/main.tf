resource "aws_iam_role" "iam_role" {
  name = "lambda_${var.AWS_LAMBDA_NAME}_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })

  inline_policy {
    name = "lambda_${var.AWS_LAMBDA_NAME}_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["logs:CreateLogGroup"]
          Effect   = "Allow"
          Resource = ["arn:aws:logs:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:*"]
        },
        {
          Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Effect   = "Allow"
          Resource = ["arn:aws:logs:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.AWS_LAMBDA_NAME}:*"]
        },
        {
          Effect = "Allow",
          Action = [
            "dynamodb:BatchGetItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem",
            "dynamodb:GetItem",
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:UpdateItem"
          ],
          Resource = [
            "arn:aws:dynamodb:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:table/${var.AWS_LAMBDA_NAME}"
          ]
        },
        # allow reading from AUTH ssm parameter
        {
          Effect = "Allow",
          Action = [
            "ssm:GetParameter"
          ],
          Resource = [
            "arn:aws:ssm:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:parameter/${var.AWS_LAMBDA_NAME}/AUTH"
          ]
        },
        # permission to decrypt ssm parameters with default kms key
        {
          Effect = "Allow",
          Action = [
            "kms:Decrypt"
          ],
          Resource = [
            "arn:aws:kms:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:key/alias/aws/ssm"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "s3:*"
          ]
          Resource = [
            "arn:aws:s3:::${var.AWS_LAMBDA_NAME}/*"
          ]
        }
      ]
    })
  }
}

resource "aws_iam_role_policy_attachment" "attach_policy_vpc_access" {
  role       = aws_iam_role.iam_role.name
  policy_arn = data.aws_iam_policy.AWSLambdaVPCAccessExecutionRole.arn
}

resource "aws_lambda_function" "lambda" {
  function_name    = var.AWS_LAMBDA_NAME
  role             = aws_iam_role.iam_role.arn
  image_uri        = "${data.aws_ecr_repository.ecr_repo.repository_url}:latest"
  package_type     = "Image"
  memory_size      = 1024
  source_code_hash = trimprefix(data.aws_ecr_image.repo_image.id, "sha256:")
  timeout          = 20

  environment {
    variables = {
      # AUTH ssm path
      AUTH            = "ssm:///${var.AWS_LAMBDA_NAME}/AUTH"
      AWS_LAMBDA_NAME = var.AWS_LAMBDA_NAME
    }
  }

  vpc_config {
    subnet_ids         = var.SUBNET_IDS
    security_group_ids = var.SECURITY_GROUP_IDS
  }
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"
}


# save AUTH into ssm
resource "aws_ssm_parameter" "AUTH" {
  name  = "/${var.AWS_LAMBDA_NAME}/AUTH"
  type  = "SecureString"
  value = var.AUTH
}

# s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = var.AWS_LAMBDA_NAME
}
