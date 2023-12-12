terraform{
	required_providers{
		aws = {
			source = "hashicorp/aws"
			version = "~> 5.0"
		}
	}
}

provider "aws" {
	region = var.region
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_image_upload_to_s3" {
  name               = "iam_for_lambda-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_image_upload_to_s3.name
}
resource "aws_lambda_permission" "image_upload_permission"{
	statement_id = "allow_image_upload_gateway"
	action = "lambda:InvokeFunction"
	function_name = aws_lambda_function.image_upload_to_s3.function_name
	principal = "apigateway.amazonaws.com"
	source_arn = "${aws_api_gateway_rest_api.image_manipulation_gateway.execution_arn}/*"
}
resource "aws_lambda_function" "image_upload_to_s3"{
	function_name = "image_upload_to_s3-${var.environment}"
	role = aws_iam_role.iam_image_upload_to_s3.arn
	runtime = "provided.al2"
	filename = "${path.module}/lambda/target/lambda/fakeS3Upload/bootstrap.zip"
	handler = "hello.handler"
}



resource "aws_api_gateway_rest_api" "image_manipulation_gateway" {
	name = "image_manipulation_gateway"
	endpoint_configuration{
		types = ["REGIONAL"]
	}
	policy = <<POLICY
	{
		"Version": "2012-10-17",
		"Statement": [
			{
				"Effect": "Allow",
				"Principal": "*",
				"Action": "execute-api:Invoke",
				"Resource": "arn:aws:execute-api:us-east-1:*"
			},
			{
				"Effect": "Deny",
				"Principal": "*",
				"Action": "execute-api:Invoke",
				"Resource": "arn:aws:execute-api:us-east-1:*",
				"Condition": {
				"StringNotEquals": {
					"aws:UserAgent": "Amazon CloudFront"
					}
				}
			}
		]
	}
	POLICY
}
resource "aws_api_gateway_resource" "upload_image_gateway_resource"{
	rest_api_id = aws_api_gateway_rest_api.image_manipulation_gateway.id
	parent_id = aws_api_gateway_rest_api.image_manipulation_gateway.root_resource_id 
	path_part = "imageUpload"
}

resource "aws_api_gateway_method" "upload_image_gateway_method" {
	rest_api_id   = aws_api_gateway_rest_api.image_manipulation_gateway.id
	resource_id   = aws_api_gateway_resource.upload_image_gateway_resource.id
	http_method   = "POST"
	authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_image_gateway_integration"{
	rest_api_id = aws_api_gateway_rest_api.image_manipulation_gateway.id
	resource_id = aws_api_gateway_resource.upload_image_gateway_resource.id
	integration_http_method = "POST"
	http_method = aws_api_gateway_method.upload_image_gateway_method.http_method 
	type = "AWS"
	uri = aws_lambda_function.image_upload_to_s3.invoke_arn

}

resource "aws_api_gateway_integration_response" "upload_image_gateway_integration_response"{
	depends_on  = [aws_api_gateway_integration.upload_image_gateway_integration]
	rest_api_id = aws_api_gateway_rest_api.image_manipulation_gateway.id
	resource_id = aws_api_gateway_resource.upload_image_gateway_resource.id
	http_method = aws_api_gateway_method.upload_image_gateway_method.http_method
	status_code = aws_api_gateway_method_response.upload_image_gateway_method_response.status_code
}

resource "aws_api_gateway_method_response" "upload_image_gateway_method_response"{
	rest_api_id = aws_api_gateway_rest_api.image_manipulation_gateway.id
	resource_id = aws_api_gateway_resource.upload_image_gateway_resource.id
	http_method = aws_api_gateway_method.upload_image_gateway_method.http_method
	status_code = "200"
}

resource "aws_api_gateway_deployment" "image_manipulation_deployment" {
  rest_api_id = aws_api_gateway_rest_api.image_manipulation_gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload_image_gateway_resource.id,
      aws_api_gateway_method.upload_image_gateway_method.id,
      aws_api_gateway_integration.upload_image_gateway_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "image_manipulation_stage" {
  deployment_id = aws_api_gateway_deployment.image_manipulation_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.image_manipulation_gateway.id
  stage_name    = var.environment 
}

resource "aws_cloudfront_distribution" "image_manipulation_cloudfront_distribution" {
	origin {
		domain_name = "${aws_api_gateway_rest_api.image_manipulation_gateway.id}.execute-api.${var.region}.amazonaws.com"
		origin_id = "${aws_api_gateway_rest_api.image_manipulation_gateway.id}.execute-api.${var.region}.amazonaws.com"
		custom_header {
			name = "User-Agent"
			value = "Amazon CloudFront"
		}
		custom_origin_config {
			http_port = "80"
			https_port = "443"
			origin_protocol_policy = "https-only"
			origin_ssl_protocols = ["TLSv1.2"]
		}
		origin_path  = "/${aws_api_gateway_stage.image_manipulation_stage.stage_name}"
	}
	enabled = true
	default_cache_behavior {
		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
		cached_methods   = ["GET", "HEAD"]
		target_origin_id = "${aws_api_gateway_rest_api.image_manipulation_gateway.id}.execute-api.${var.region}.amazonaws.com"

		forwarded_values {
			query_string = false
			
			cookies {
				forward = "none"
			}
		}

	viewer_protocol_policy = "allow-all"
	min_ttl                = 0
	default_ttl            = 3600
	max_ttl                = 86400
	}
	restrictions {
		geo_restriction {
			restriction_type = "whitelist"
			locations = ["US","CA","GB","DE"]
		}
	}
	viewer_certificate {
    		cloudfront_default_certificate = true
	}
	web_acl_id = aws_wafv2_web_acl.rate_limit_acl.arn
}
resource "aws_wafv2_web_acl" "rate_limit_acl" {
	name        = "rate-based-acl"
	scope       = "CLOUDFRONT"

	default_action {
		allow {}
	}

	rule {
		name     = "rate_limit_rulr"
		priority = 1

		action {
			block {}
		}

		statement {
			rate_based_statement {
				limit              = 300
				aggregate_key_type = "IP"

				scope_down_statement {
					geo_match_statement {
						country_codes = ["US", "CA","GB","DE"]
					}
				}
			}
		}

		visibility_config {
			cloudwatch_metrics_enabled = false
			metric_name                = "rate_limit_rule_metric"
			sampled_requests_enabled   = false
		}
	}
	visibility_config {
		cloudwatch_metrics_enabled = false
		metric_name                = "rate_limit_acl_metric"
		sampled_requests_enabled   = false
	}
}
