## Provider
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"
}

provider "aws" {
  alias  = "oregon"
  region = "us-west-2"
}

## Route53
resource "aws_route53_zone" "private_bedrock" {
  name = "bedrock.in"

  vpc {
    vpc_id = module.vpc_seoul.vpc_id
  }
}

resource "aws_route53_record" "bedrock_virginia" {
  zone_id = aws_route53_zone.private_bedrock.zone_id
  name    = "virginia.bedrock.in"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.virginia_bedrock.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.virginia_bedrock.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

## VPC
module "vpc_seoul" {
  source   = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.seoul
  }

  name = format("%s-seoul-vpc", local.name)

  cidr            = local.vpc_cidr_seoul
  azs             = local.azs_seoul
  public_subnets  = [for k, v in local.azs_seoul : cidrsubnet(local.vpc_cidr_seoul, 8, k)]
  private_subnets = [for k, v in local.azs_seoul : cidrsubnet(local.vpc_cidr_seoul, 8, k + 8)]
  intra_subnets   = [for k, v in local.azs_seoul : cidrsubnet(local.vpc_cidr_seoul, 8, k + 16)]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true
}

module "vpc_virginia" {
  source = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.virginia
  }

  name = format("%s-virginia-vpc", local.name)

  cidr            = local.vpc_cidr_virginia
  azs             = local.azs_virginia
  public_subnets  = [for k, v in local.azs_virginia : cidrsubnet(local.vpc_cidr_virginia, 8, k)]
  private_subnets = [for k, v in local.azs_virginia : cidrsubnet(local.vpc_cidr_virginia, 8, k + 8)]
  intra_subnets   = [for k, v in local.azs_virginia : cidrsubnet(local.vpc_cidr_virginia, 8, k + 16)]

  enable_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  manage_default_network_acl    = true
  manage_default_route_table    = true
  manage_default_security_group = true
}

## Peering
resource "aws_vpc_peering_connection" "seoul_virginia" {
  provider = aws.seoul

  vpc_id      = module.vpc_seoul.vpc_id
  peer_vpc_id = module.vpc_virginia.vpc_id
  peer_region = "us-east-1"
}

resource "aws_vpc_peering_connection_accepter" "seoul_virginia" {
  provider = aws.virginia

  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_virginia.id
  auto_accept               = true
}

## Endpoint
resource "aws_vpc_endpoint" "virginia_bedrock" {
  provider = aws.virginia

  vpc_id              = module.vpc_virginia.vpc_id
  service_name        = "com.amazonaws.us-east-1.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = module.vpc_virginia.private_subnets
}

## EC2
module "sg_bedrock_client" {
  source = "terraform-aws-modules/security-group/aws"
  providers = {
    aws = aws.seoul
  }

  name   = format("%s-client-sg", local.name)
  vpc_id = module.vpc_seoul.vpc_id

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "ec2_bedrock_client" {
  source = "terraform-aws-modules/ec2-instance/aws"
  providers = {
    aws = aws.seoul
  }

  name = format("%s-client-ec2", local.name)

  instance_type          = "m5.large"
  subnet_id              = module.vpc_seoul.private_subnets[0]
  vpc_security_group_ids = [module.sg_bedrock_client.security_group_id]

  create_iam_instance_profile = true
  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

