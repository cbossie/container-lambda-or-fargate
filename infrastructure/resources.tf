
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

}

#S3
resource "aws_s3_bucket" "output_bucket" {
  bucket = "lambda-or-fargate-bucket-${data.aws_caller_identity.current.account_id}"
}


# ECR

resource "aws_ecr_repository" "fargatelambda_repo" {
  name                 = "fargatelambda-repo"
  image_tag_mutability = "MUTABLE"
}

#ECS
module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "4.1.2"


  cluster_name = "ecs-fargate"



}

resource "aws_iam_policy" "ecs_policy" {
  name        = "ecs-policy"
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


module "iam_iam_assumable_role" {
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
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
}



resource "aws_ecs_task_definition" "service" {
  family = "lambdaorfargate"
  container_definitions = jsonencode([
    {
      name                     = "lambdaorfargate"
      image                    = "${aws_ecr_repository.fargatelambda_repo.name}:latest"
      requires_compatibilities = ["FARGATE"]
      network_mode             = "awsvpc"
      cpu                      = 1024
      memory                   = 2048
      essential                = true
      environment = [
        {
          name  = "OUTPUT_BUCKET",
          value = "${aws_s3_bucket.output_bucket.bucket}"
        }
      ],

  }])
}