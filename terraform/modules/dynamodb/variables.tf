variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev)"
  type        = string
}

variable "enable_point_in_time_recovery" {
  description = "Enable DynamoDB point-in-time recovery (off by default to stay Free Tier friendly)"
  type        = bool
  default     = false
}
