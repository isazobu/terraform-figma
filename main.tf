
provider "aws" {
  region = var.aws_region
  access_key = "XXX" // TODO: Replace with actual access key
  secret_key = "YYY" // TODO: Replace with actual secret key 
}




data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/dist/package"
  output_path = "${path.module}/dist/lambda_function.zip"
  depends_on  = [null_resource.lambda_build]
}

resource "null_resource" "lambda_build" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/build_lambda.sh"
  }
}





resource "aws_s3_bucket" "source_bucket" {
  bucket = var.source_bucket_name
}


resource "aws_s3_bucket" "destination_bucket" {
  bucket = var.destination_bucket_name
}


resource "aws_iam_role" "lambda_role" {
  name = "s3_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_role_policy" "lambda_policy" {
  name = "s3_lambda_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.source_bucket.arn}/*",
          "${aws_s3_bucket.destination_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "process_file" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.lambda_function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "main.handler"
  runtime         = "python3.9"
  timeout         = 60
  memory_size     = 256
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.destination_bucket.id
      ANTHROPIC_API_KEY = var.anthropic_api_key
      OPENAI_API_KEY = var.openai_api_key
    }
  }

  depends_on = [null_resource.lambda_build]
}


resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.source_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.process_file.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".html"
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_file.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.source_bucket.arn
}