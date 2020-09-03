data "aws_caller_identity" "current" {}

locals {
  environment = var.workspace_to_environment["test"]
  acc_id      = data.aws_caller_identity.current.account_id
}

variable "project" {
  default = "bug-test"
}

data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    #bucket   = "${var.vpc_remote_state_bucket_base}.${var.environment}"
    bucket   = "com.dodax.infrastructure.terraform.testing"
    key      = "infrastructure-vpc/terraform.tfstate"
    region   = "eu-central-1"
    role_arn = "arn:aws:iam::609350192073:role/jenkins_executor"
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.35.128.0/17"
  tags       = { "Name" = "${var.project}-Infrastructure" }
}

#------------------------------------------#
# Requester's side of the connection
#------------------------------------------#

resource "aws_vpc_peering_connection" "peer-infrastructure" {
  vpc_id        = aws_vpc.vpc.id
  peer_vpc_id   = data.terraform_remote_state.infrastructure.outputs.vpc-id
  peer_owner_id = data.terraform_remote_state.infrastructure.outputs.account-id
  peer_region   = "eu-central-1"
  auto_accept   = true

  tags = { "Name" = "${var.project}-Infrastructure" }
}

#------------------------------------------#
# Accepter's side of the connection
#------------------------------------------#

resource "aws_vpc_peering_connection_accepter" "peer" {
  provider = aws.infrastructure

  vpc_peering_connection_id = aws_vpc_peering_connection.peer-infrastructure.id
  auto_accept               = true

  tags = { "Name" = "${var.project}-Infrastructure" }
}