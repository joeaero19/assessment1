########## Create ECR repo to hold the app image ##########

resource "aws_ecr_repository" "aws-ecr" {
  name = "my-app"
  tags = {
    Name        = "${var.app_name}-ecr"
    Environment = var.app_environment
  }
}

########## Check docker files for changes ##########
module "path_hash" {
  source = "github.com/claranet/terraform-path-hash?ref=v0.2.0"
  path   = "./docker_files"
}

########## Build and push the image to ECR repo ##########
resource "null_resource" "build_docker_image" {
  triggers = {
    new_ecr_repo                =    aws_ecr_repository.aws-ecr.repository_url
    docker_files_changes =    module.path_hash.result

  }
  provisioner "local-exec" {
  command = "chmod -R 755 ./docker_files && cd docker_files/app && ./deploy-image.sh ${aws_ecr_repository.aws-ecr.repository_url} ${var.ecr_repo_name}"
  }
}
