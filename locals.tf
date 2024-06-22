locals {
  name = "ts-bedrock-cross-region"

  vpc_cidr_seoul    = "10.0.0.0/16"
  vpc_cidr_virginia = "10.10.0.0/16"
  vpc_cidr_oregon   = "10.20.0.0/16"

  azs_seoul    = ["ap-northeast-2a", "ap-northeast-2c"]
  azs_virginia = ["us-east-1a", "us-east-1c"]
  azs_oregon   = ["us-west-2a", "us-west-2c"]
}
