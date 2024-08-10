provider "aws" {
  region = var.aws_region
  shared_credentials_files = ["~/.aws/credentials"]
}

# Crear un rol IAM para la función Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com",
        },
      },
    ],
  })
}

# Adjuntar una política básica de Lambda al rol
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Crear la función Lambda
resource "aws_lambda_function" "demo_terra_lambda" {
  filename         = "${path.module}/../lambda/lambda_demo.zip"  # Archivo zip con tu código
  function_name    = "my_lambda_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"  # Cambia según tu versión de Python
}

# Crear una API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "my-api-terra-demo"
  description = "My API Gateway"
}


# Crear un recurso nuevo en la API Gateway existente
resource "aws_api_gateway_resource" "new_resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id  # Puedes usar root_resource_id o cualquier otro parent_id
  path_part   = "saludo"  # Define el nombre del nuevo recurso
}


# Crear un método para el nuevo recurso
resource "aws_api_gateway_method" "new_resource_method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.new_resource.id
  http_method   = "GET"  # Puedes usar otros métodos como POST, PUT, DELETE, etc.
  authorization = "NONE"  # Cambia según tu configuración de autorización
}


# Integrar el nuevo método con la función Lambda
resource "aws_api_gateway_integration" "new_resource_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.new_resource.id
  http_method             = aws_api_gateway_method.new_resource_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.demo_terra_lambda.arn}/invocations"
}


# Crear un recurso raíz en la API Gateway
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

# Crear un método ANY para el recurso
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Integrar el método con la función Lambda
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.demo_terra_lambda.arn}/invocations"
}

# Crear una política para permitir que la API Gateway invoque la función Lambda
resource "aws_lambda_permission" "api_gateway_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.demo_terra_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Crear el despliegue de la API Gateway
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.integration,
    aws_api_gateway_integration.new_resource_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "test"
}