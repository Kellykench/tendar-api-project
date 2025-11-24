terraform {
  backend "s3" {
    bucket         = "tendar-terraform-state-bucket-9965-0203-0188"
    key            = "tendar/infrastructure.tfstate"
    region         = "us-west-1"
    encrypt        = true
    dynamodb_table = "tendar-terraform-locks"
  }
}