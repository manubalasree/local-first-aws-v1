variable "project" {
  description = "Project name, used in resource names."
  type        = string
  default     = "floci-to-cloud"
}

variable "environment" {
  description = "Environment name (local or prod)."
  type        = string
}

variable "bucket_name" {
  description = "Globally unique name for the site bucket."
  type        = string
}

variable "index_html_path" {
  description = "Absolute path to the index.html to upload. Must be absolute: Terragrunt runs the module from a cache directory."
  type        = string
}

variable "force_destroy" {
  description = "Allow destroying the bucket even when it contains objects (teardown convenience)."
  type        = bool
  default     = false
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}
