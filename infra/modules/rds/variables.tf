variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "db_identifier" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "allowed_sg_id" {
  description = "Security group ID allowed to connect to the DB (EKS nodes SG)"
  type        = string
}
