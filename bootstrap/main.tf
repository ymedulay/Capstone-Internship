#creates the S3 bucket that the backend uses

resource "aws_s3_bucket" "backend_for_statefile" {
  bucket = "dulay-finalproject-terraform-state"

  lifecycle {
    prevent_destroy = true #protects state file from accidental deletion
  }
}

resource "aws_s3_bucket_versioning" "backend_versioning" {
  bucket = "dulay-finalproject-terraform-state"
  versioning_configuration {
    status = "Enabled" #turns on versioning for the bucket
    #to recover previous versions
  }
}