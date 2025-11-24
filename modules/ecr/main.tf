resource "aws_ecr_repository" "api_repo" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-api-repo"
  }
}

output "api_repo_url" {
  value = aws_ecr_repository.api_repo.repository_url
}