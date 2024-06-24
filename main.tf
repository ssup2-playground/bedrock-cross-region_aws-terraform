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
  name    = "virginia.runtime.bedrock.in"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.virginia_bedrock.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.virginia_bedrock.dns_entry[0].hosted_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "bedrock_oregon" {
  zone_id = aws_route53_zone.private_bedrock.zone_id
  name    = "oregon.runtime.bedrock.in"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.oregon_bedrock.dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.oregon_bedrock.dns_entry[0].hosted_zone_id
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

module "vpc_oregon" {
  source = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.oregon
  }

  name = format("%s-oregon-vpc", local.name)

  cidr            = local.vpc_cidr_oregon
  azs             = local.azs_oregon
  public_subnets  = [for k, v in local.azs_oregon : cidrsubnet(local.vpc_cidr_oregon, 8, k)]
  private_subnets = [for k, v in local.azs_oregon : cidrsubnet(local.vpc_cidr_oregon, 8, k + 8)]
  intra_subnets   = [for k, v in local.azs_oregon : cidrsubnet(local.vpc_cidr_oregon, 8, k + 16)]

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

resource "aws_route" "vpc_seoul_to_virginia" {
  provider = aws.seoul

  for_each                  = toset(module.vpc_seoul.private_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = local.vpc_cidr_virginia
  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_virginia.id
}

resource "aws_route" "vpc_virginia_to_vpc_seoul" {
  provider = aws.virginia

  for_each                  = toset(module.vpc_virginia.private_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = local.vpc_cidr_seoul
  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_virginia.id
}

resource "aws_vpc_peering_connection" "seoul_oregon" {
  provider = aws.seoul

  vpc_id      = module.vpc_seoul.vpc_id
  peer_vpc_id = module.vpc_oregon.vpc_id
  peer_region = "us-west-2"
}

resource "aws_vpc_peering_connection_accepter" "seoul_oregon" {
  provider = aws.oregon

  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_oregon.id
  auto_accept               = true
}

resource "aws_route" "vpc_seoul_to_oregon" {
  provider = aws.seoul

  for_each                  = toset(module.vpc_seoul.private_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = local.vpc_cidr_oregon
  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_oregon.id
}

resource "aws_route" "vpc_oregon_to_vpc_seoul" {
  provider = aws.oregon

  for_each                  = toset(module.vpc_oregon.private_route_table_ids)
  route_table_id            = each.value
  destination_cidr_block    = local.vpc_cidr_seoul
  vpc_peering_connection_id = aws_vpc_peering_connection.seoul_oregon.id
}

## Endpoint
module "sg_virginia_bedrock_vpc_endpoint" {
  source = "terraform-aws-modules/security-group/aws"
  providers = {
    aws = aws.virginia
  }

  name   = format("%s-bedrock-vpc-endpoint-sg", local.name)
  vpc_id = module.vpc_virginia.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "https"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_vpc_endpoint" "virginia_bedrock" {
  provider = aws.virginia

  vpc_id              = module.vpc_virginia.vpc_id
  service_name        = "com.amazonaws.us-east-1.bedrock-runtime"
  vpc_endpoint_type   = "Interface"

  security_group_ids = [module.sg_virginia_bedrock_vpc_endpoint.security_group_id]

  subnet_ids = module.vpc_virginia.private_subnets
}

resource "aws_vpc_endpoint_policy" "virginia_bedrock_invoke" {
  provider = aws.virginia

  vpc_endpoint_id = aws_vpc_endpoint.virginia_bedrock.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowAll",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        "Resource" : "*"
      }
    ]
  })
}

module "sg_oregon_bedrock_vpc_endpoint" {
  source = "terraform-aws-modules/security-group/aws"
  providers = {
    aws = aws.oregon
  }

  name   = format("%s-bedrock-vpc-endpoint-sg", local.name)
  vpc_id = module.vpc_oregon.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "https"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_vpc_endpoint" "oregon_bedrock" {
  provider = aws.oregon

  vpc_id              = module.vpc_oregon.vpc_id
  service_name        = "com.amazonaws.us-west-2.bedrock-runtime"
  vpc_endpoint_type   = "Interface"

  security_group_ids = [module.sg_oregon_bedrock_vpc_endpoint.security_group_id]

  subnet_ids = module.vpc_oregon.private_subnets
}

resource "aws_vpc_endpoint_policy" "oregon_bedrock_invoke" {
  provider = aws.oregon

  vpc_endpoint_id = aws_vpc_endpoint.oregon_bedrock.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowAll",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ],
        "Resource" : "*"
      }
    ]
  })
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
    AmazonBedrockFullAccess = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
  }
}

