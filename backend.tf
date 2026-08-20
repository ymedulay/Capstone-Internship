#tells terraform to store the state file in an S3 bucket, NOT LOCALLY
#why remote state matters:
#1. prevents state loss if your device dies
#2. allows team collaboration
#3. avoids two tf apply at once errors
#4. keeps sensitive outputs secure

terraform {
  backend "s3" {
    bucket       = "dulay-finalproject-terraform-state" #where the state file will be stored
    key          = "terraform.tfstate"                  #name of the state file inside the bucket
    region       = "ap-southeast-1"
    encrypt      = true #enables server-side encryption, protects the state file
    use_lockfile = true #enables state locking, prevents corruption
  }
}