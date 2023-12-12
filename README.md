
#  JasperHealth-Takehome-assesment

## Prerequisites

  1. Install [Rust, Cargo](https://www.rust-lang.org/tools/install), [Lambda Crate](https://www.cargo-lambda.info/guide/installation.html), [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

## Asumptions
For this project I decided to add a particular story to help define how we would expect users to interact with this lambda and the greater context that this lambda exists in. Below are the assumptions in no particular order
1. This lambda has the responsibility of uploading an image to S3 to later be processed.
2. The context for this lambda is that its a part of an online image manipulation service
3. Users do not need an account or be authorized to use the service
4. We will only serve users in NA/EU

## Run Locally

Clone the project

```bash
  git clone git@github.com:Spheny1/JasperHealth-Takehome-assesment.git
```

Build Lambda

```bash
  cd lambda
  cargo lambda build --release --output-format zip
```

Apply Terraform Plan

```bash
  export REGION={AWS-REGION}
  export ENV={DESIRED-ENV}
  terraform init
  terraform apply -var="region=$REGION" -var="environment=$ENV"
```



## Points of Improvement

This project was slated to take 2-3 hours and I am content with the project as is. Given more time here are some improvements I would make  
1. Currently the Api Gateway is only checking for the user-agent that is forwaded by the CloudFront distribution a more secure solution would be to have the custom header whose value could be stored in Secrets Manager and  be rotated on a schedule. Then, create a Lambda Authorizer function to check for this value in Secrets Manager and authorize the request that way.
2. Setting up shared resources to reuse resources such as IAM Roles and the Api Gateway. Currently this will deploy a new Api Gateway based on the environment parameter given a more DRY solution could be to reuse the Gateway and have a new deployment based on the environment specified.
3. Setup Concourse CICD pipeline. I do not have it deployed/setup locally if time permits maybe Ill get this added before the interview.


