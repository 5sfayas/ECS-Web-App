variable "AWS_ACCESS_KEY"{}
variable "AWS_SECRET_KEY"{}
variable "AWS_REGION"{
default = "eu-west-1"
}
variable "app_port"{
    default = 3000
}
variable "web_port"{
    default = 80
}
variable "desired_count"{
    default = 1
}
variable "alb-rule"{
    default = ""
}
variable "host_header"{
    default = ""
}
variable "cluster_name"{
    default = ""
}
variable "vpc_id"{
    default = ""
}
variable "health_url"{
    default ="/api"
}