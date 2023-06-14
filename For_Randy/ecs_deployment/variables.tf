variable "security_group_name" {
  default = "hello-observability"
  type    = string
}
variable "instance_name" {
  default = "hello-observability"
}
variable "instance_type" {
  default = "t3.micro"
}
variable "vpc_id" {
  type        = string
  description = "VPC id"
  default     = ""
}
variable "cluster_name" {
  default = "dv-grafana-java-tracing"
}
variable "environment" {
  default = "dev"
}
variable "instance_created_by" {
  default = "Terraform"
}
variable "vpc_security_group" {
  default = ""
}

variable "load_balancer_name" {
  default = "hello-observability"
}
variable "load_balancer_type" {
  default = "application"
}
variable "public_subnet_ids" {
  default = [
  ]
}
variable "private_subnets_id" {
  default = [
  ]
}
variable "task_definition_name" {
  type        = string
  description = "Task Definition Name"
  default     = "hello-observability"
}
variable "aws_region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}
variable "command" {
  type        = list(string)
  description = "command to run on the docker container"
  default     = []
}
variable "container_port" {
  type        = number
  description = "the port the container is running on"
  default     = 8080
}
variable "host_port" {
  type        = number
  description = "the port on the host"
  default     = 8080
}
variable "protocol" {
  type        = string
  description = "protocol"
  default     = "tcp"
}
variable "app_environment_vars" {
  type        = list(map(string))
  description = "environment variable needed by the application"
  default = [
    {
      "name"  = "BUCKET1",
      "value" = "test1"
    }
  ]
}
variable "aws_iam_role" {
  type        = string
  description = "aws iam role ARN"
}
variable "ecs_container_name" {
  type        = string
  description = "ECS Container Name"
  default     = "hello-observability02"
}
variable "ecs_service_name" {
  type        = string
  description = "ECS Service Name"
  default     = "hello-observability02"
}
variable "ecr_image_url" {
  type        = string
  description = "ECR Image URL"
}
variable "desired_count" {
  type        = number
  description = "No of Tasks"
  default     = 1
}
variable "target_group_name" {
  default = "hello-observability"
}