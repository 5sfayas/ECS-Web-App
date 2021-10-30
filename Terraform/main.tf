# Create Cluster
data "aws_vpc" "vpc" {
  id = var.vpc_id
}


resource "aws_ecs_cluster" "cluster" {
    name = var.cluster_name
    capacity_providers = ["FARGATE","FARGATE_SPOT"]
    default_capacity_provider_strategy {
        capacity_provider = "FARGATE"
    }
}


# Deploy Container 
data "template_file" "template" {
    template = file("./templates/container-definition.json")
    vars = {
        region            = var.AWS_REGION
        app_port          = var.container_port
        web_port          = var.nginx_port
    }
}

resource "aws_ecs_task_definition" "task_definition" {
    container_definitions = data.template_file.template.rendered
    family = "SideCar"
    requires_compatibilities = ["FARGATE"]
    network_mode = "bridge"
    execution_role_arn = "arn:aws:iam::YOurAccountID:role/ecsTaskExecutionRole"
    task_role_arn = "arn:aws:iam::YourAccountID:role/ecsTaskExecutionRole"
}


resource "aws_ecs_service" "ecs_service" {
  cluster = aws_ecs_cluster.cluster.id
  name = "WebApp"
  task_definition = aws_ecs_task_definition.task_definition.arn
  iam_role = "arn:aws:iam::YourAccountID:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
  load_balancer {
    target_group_arn = aws_alb_target_group.target_group.arn
    container_name = "nginx-container"
    container_port = var.nginx_port
  }
  desired_count = var.desired_count
 lifecycle {
    ignore_changes = [desired_count]
  }
}



# Create Subnet and Security Group for ALB

# Reference resources
data "aws_availability_zones" "available" {
}

# Create Subnet
resource "aws_subnet" "fargate_public" {
    count = 1
    cidr_block              = "10.0.0.1/24"
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    vpc_id                  = data.aws_vpc.vpc.id
    map_public_ip_on_launch = true
    
    tags = {
    Name = "WebApp"
  }
}

# Security group for public subnet holding load balancer
resource "aws_security_group" "alb" {
    name        = "alb-sg"
    description = "Allow access on port 443 only to ALB"
    vpc_id      = data.aws_vpc.vpc.id

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        self        = true
    }
}

# Allow ingress rule appropriate to HTTP Protocol used
resource "aws_security_group_rule" "tcp_443" {
    type              = "ingress"
    from_port         = 443
    to_port           = 443
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = aws_security_group.alb.id
}


resource "aws_security_group_rule" "tcp_80" {
    type              = "ingress"
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
    security_group_id = aws_security_group.alb.id
}

#create ALB
resource "aws_alb" "fargate" {
  name            = ""
  subnets         = aws_subnet.fargate_public.*.id
  security_groups = [aws_security_group.alb.id]
}

resource "aws_alb_target_group" "target_group" {
    name = "Nginx_TG"
    target_type = "instance"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc_id
    deregistration_delay = 20

    health_check {
        enabled = true
        path = var.health_url
        interval = 10
        protocol = "HTTP"
        port = "traffic-port"
        timeout = 5
        healthy_threshold = 2
        unhealthy_threshold = 2
        matcher = "200"
    }
}

resource "aws_alb_listener" "listener" {
    load_balancer_arn = aws_alb.fargate.id
    port              = "80"
    protocol          = "HTTP"
    default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group.arn
    }

    condition {
    host_header {
      values = ["webapp.com"]
    }
  }
    condition {
        path_pattern {
        values = var.alb_rule
        }

    }
}