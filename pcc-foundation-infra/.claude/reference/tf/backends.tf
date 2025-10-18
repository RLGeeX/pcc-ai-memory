terraform {
  backend "gcs" {
    bucket = "cs-tfstate-us-east4-7351f954f21d4c0c9476017588a0fb91"
    prefix = "terraform"
  }
}
