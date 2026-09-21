provider "aws"  {

}

terraform {
    backend "s3"  {
        bucket = "terraform-ressources-github-actions"
        region = "us-east-1"
        key = "github-actions/terraform.tfstate"
        encrypt = true
        dynamodb_table = "terraform-ressources-githublock"
    }
}