variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile"
  default     = "academy-front"
}

variable "backend_image" {
  type        = string
  description = "Docker image for backend"
  default     = "aceofglass14/pokedx-backend:latest"
}

variable "desired_capacity" {
  type        = number
  description = "Number of EC2 instances in ASG"
  default     = 4
}

variable "min_size" {
  type    = number
  default = 4
}

variable "max_size" {
  type    = number
  default = 6
}
