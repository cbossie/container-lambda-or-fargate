#This is so you will have a VPC to run in
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "container-vpc"
  cidr   = var.vpccidr
  enable_nat_gateway = true
  create_igw         = true
  azs                    = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets        = slice(cidrsubnets(var.vpccidr, 4, 4, 4, 4, 4, 4), 0, 3)
  public_subnets         = slice(cidrsubnets(var.vpccidr, 4, 4, 4, 4, 4, 4), 3, 6)
  create_vpc             = true
  one_nat_gateway_per_az = true
  count = var.include_vpc ? 1 : 0
}

#S3
resource "aws_s3_bucket" "output_bucket" {
  bucket = "lambda-or-fargate-bucket-${data.aws_caller_identity.current.account_id}"
}

#ECS
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "4.1.2"


  cluster_name = "ecs-fargate-or-lambda"
}

resource "aws_iam_policy" "ecs_policy" {
  name        = "ecs-s3-policy"
  path        = "/"
  description = "ECS Policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}


module "iam_iam-assumable-role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version   = "5.9.1"
  role_name = "fargate_or_lambda_role"
  trusted_role_services = [
    "ecs-tasks.amazonaws.com",
    "lambda.amazonaws.com"
  ]
  trusted_role_actions = ["sts:AssumeRole"]
  custom_role_policy_arns = [
    aws_iam_policy.ecs_policy.arn,
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
  create_role       = true
  role_requires_mfa = false
}

resource "aws_ecs_task_definition" "fargate-def" {
  family                   = "lambdaorfargate"
  execution_role_arn       = module.iam_iam-assumable-role.iam_role_arn
  task_role_arn            = module.iam_iam-assumable-role.iam_role_arn
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions = jsonencode([
    {
      name  = "lambdaorfargate"
      image = "${var.ecr_repository}"

      cpu       = 1024
      memory    = 2048
      essential = true
      environment = [
        {
          name  = "OUTPUT_BUCKET",
          value = "${aws_s3_bucket.output_bucket.bucket}"
        },
        {
          name  = "FILE_NAME",
          value = "CONTAINER_"
        }

      ],

  }])
   runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

#Lambda
module "lambda_function_container_image" {
  source = "terraform-aws-modules/lambda/aws"

  function_name  = "lambda-function-with-shared-image"
  description    = "Function with Shared Image"
  create_role    = false
  create_package = false
  lambda_role    = module.iam_iam-assumable-role.iam_role_arn
  image_uri      = var.ecr_repository
  package_type   = "Image"
  memory_size    = 512
  environment_variables = {
    "OUTPUT_BUCKET" = "${aws_s3_bucket.output_bucket.bucket}"
    "FILE_NAME"     = "LAMBDA_"
  }
}

