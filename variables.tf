variable "region" {
	type = string
	default = "us-east-2"
}

variable "environment" {
	type = string
	default = "staging"
}
variable "path_to_zip"{
	type = string
	default = "lambda/target/lambda/fakeS3Upload"
}
