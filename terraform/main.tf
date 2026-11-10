# This is the "blueprint" for our container registry
resource "aws_ecr_repository" "devops_repo" {
  # The name for your repository
  name = "devops-repo"

  # This setting makes sure you can't accidentally overwrite an image tag
  image_tag_mutability = "IMMUTABLE"

  # This block enables vulnerability scanning when you push an image
  image_scanning_configuration {
    scan_on_push = true
  }

  # Checkov CKV_AWS_136: encrypt images at rest with KMS instead of the
  # default AES256. With no kms_key set, AWS uses its managed key
  # (aws/ecr), so there is no extra key to create or pay for.
  encryption_configuration {
    encryption_type = "KMS"
  }

  # Tags are good practice for organization
  tags = {
    Environment = "Testing"
    ManagedBy   = "DevOps Class"
  }
}

# This "output" block will print the registry's URL after it's created
output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.devops_repo.repository_url
}
