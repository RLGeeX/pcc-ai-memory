variable "billing_account" {
  description = "The ID of the billing account to associate projects with"
  type        = string
  default     = "01AFEA-2B972B-00C55F"
}

variable "org_id" {
  description = "The organization id for the associated resources"
  type        = string
  default     = "146990108557"
}

variable "billing_project" {
  description = "The project id to use for billing"
  type        = string
  default     = "cs-host-a785c19cb0aa4d73b60089"
}

variable "folders" {
  description = "Folder structure as a map"
  type        = map
}

variable "application_enabled_folder_paths" {
  description = "The folder paths to enable resource manager capability"
  type        = list
}
