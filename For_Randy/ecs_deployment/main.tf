terraform {
  backend "s3" {
    bucket = "java-springboot-demo-app-traces-grafana"
    key    = "java-springboot-demo-app-traces-grafana"
    region = "us-east-1"
  }
}
resource "random_string" "lt_prefix" {
  length  = 8
  upper   = false
  special = false
}
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.cluster_name
  tags = {
    Environment = var.environment
    CreatedBy   = var.instance_created_by
  }
}
resource "aws_launch_template" "ecs_launch_template" {
  name                   = "java-springboot-demo-${random_string.lt_prefix.result}"
  update_default_version = true
  credit_specification {
    cpu_credits = "unlimited"
  }
  disable_api_stop        = false
  disable_api_termination = false
  ebs_optimized           = true
  iam_instance_profile {
    arn = "arn:aws:iam::<AWS_ACCOUNT_ID>:instance-profile/dev-ephemeral-ecs-agent"
  }

  image_id = data.aws_ami.aws_optimized_ecs.id

  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  key_name                             = "<KEY_NAME>"
  monitoring {
    enabled = false
  }

  network_interfaces {
    associate_public_ip_address = true
    subnet_id = "subnet-02fc625167359aa1f"
    security_groups             = [var.vpc_security_group, aws_security_group.ec2_security_group.id]
  }
  user_data = base64encode(templatefile("./user-data.sh", { cluster_name = var.cluster_name }))
}

data "aws_ami" "aws_optimized_ecs" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn-ami*amazon-ecs-optimized"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["amazon"] # AWS
}

resource "aws_autoscaling_group" "ecs_asg" {
  name_prefix = "java-springboot-demo-${random_string.lt_prefix.result}"
  termination_policies = [
    "OldestInstance"
  ]
  default_cooldown          = 30
  health_check_grace_period = 240
  max_size                  = 20
  min_size                  = 0
  desired_capacity          = 0
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = aws_launch_template.ecs_launch_template.latest_version
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }
  lifecycle {
    create_before_destroy = true
  }
  vpc_zone_identifier = var.private_subnets_id
  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}
resource "aws_ecs_capacity_provider" "ecs-provider" {
  name = "java-springboot-demo_grafana_cloud_DefaultECSCapacityProvider-${random_string.lt_prefix.result}"
  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_asg.arn
    managed_termination_protection = "DISABLED"
    managed_scaling {
      maximum_scaling_step_size = 3
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "ecs-cluster-provider" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.ecs-provider.name]
  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.ecs-provider.name
  }
}
resource "aws_alb" "load_balancer" {
  name               = var.load_balancer_name
  load_balancer_type = var.load_balancer_type
  subnets            = var.public_subnet_ids
  security_groups    = [var.vpc_security_group]
}

resource "aws_lb_target_group" "target_group" {
  name        = var.target_group_name
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id
  lifecycle {
    create_before_destroy = true
  }
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200,302"
    healthy_threshold   = "5"
    unhealthy_threshold = "5"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.load_balancer.arn
  port              = var.container_port
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}
resource "aws_security_group" "ec2_security_group" {
  name_prefix = var.security_group_name
  vpc_id      = var.vpc_id
  description = "Security group for prometheus server - grafana cloud"
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group_rule" "rule_node_exporter" {
  type              = "ingress"
  from_port         = 9100
  to_port           = 9100
  protocol          = "tcp"
  description       = "prometheus node exporter"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_security_group.id
}
resource "aws_security_group_rule" "rule_prometheus_server" {
  type              = "ingress"
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  description       = "prometheus server"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_security_group.id
}
resource "aws_security_group_rule" "rule_cadvisor" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  description       = "cadvisor"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_security_group.id
}

resource "aws_security_group_rule" "rule_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  description       = "ssh"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.ec2_security_group.id
}

resource "aws_ecs_task_definition" "ecs-task" {
  family             = var.task_definition_name
  execution_role_arn = var.aws_iam_role
  volume {
    name      = "root"
    host_path = "/"
  }
  volume {
    name      = "var_run"
    host_path = "/var/run"
  }
  volume {
    name      = "sys"
    host_path = "/sys"
  }
  volume {
    name      = "var_lib_docker"
    host_path = "/var/lib/docker/"
  }
  volume {
    name      = "cgroup"
    host_path = "/cgroup"
  }
  volume {
    name      = "dev_disk"
    host_path = "/dev/disk/"
  }
  volume {
    name      = "hello-observability-log"
    host_path = "/cloud/logs/hello-observability.log"
  }
  volume {
    name      = "access-log"
    host_path = "/cloud/logs/access_log.log"
  }
  volume {
    name      = "load-generator-script"
    host_path = "/hello-observability/load-generator.sh"
  }
  volume {
    name      = "agent-config"
    host_path = "/etc/grafana-agent/"
  }
  volume {
    name      = "agent"
    host_path = "/tmp/agent"
  }

  container_definitions = jsonencode([
    {
      name              = "load-generator"
      image             = "<Loadgen_IMAGE_URL>"
      memoryReservation = 50
      essential         = false
      command           = ["/bin/sh", "-c", "while true; do curl http://hello-observability:8080/hello; sleep 10s; done"]
      logConfiguration = {

        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "dv-grafana-traces",
          "awslogs-stream-prefix" = "dv-grafana-loadgen",
          "awslogs-region"        = var.aws_region
        }
      }
    },
    {
      name              = "grafana-agent"
      image             = "grafana/agent:v0.25.1"
      memoryReservation = 50
      essential         = true
      entryPoint = [
        "/bin/agent",
        "-config.file=/etc/agent-config/agent.yaml",
        "-metrics.wal-directory=/tmp/agent/wal",
        "-enable-features=integrations-next",
        "-config.expand-env",
        "-config.enable-read-api"
      ]
      environment = [
        {
          "name" : "HOSTNAME",
          "value" : "agent"
        },
      ]
      mountPoints = [
        {
          "readOnly"      = false,
          "containerPath" = "/etc/agent-config",
          "sourceVolume"  = "agent-config"
        },
        {
          "readOnly"      = false,
          "containerPath" = "/tmp/hello-observability",
          "sourceVolume"  = "hello-observability-log"
        },
        {
          "readOnly"      = false,
          "containerPath" = "/tmp/access-log",
          "sourceVolume"  = "access-log"
        },
        {
          "readOnly"      = false,
          "containerPath" = "/etc/agent",
          "sourceVolume"  = "agent"
        },
      ]
      portMappings = [
        {
          containerPort = 4317
          hostPort      = 4317
        }
      ]
      logConfiguration = {

        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "dv-grafana-traces",
          "awslogs-stream-prefix" = "dv-grafana-agent",
          "awslogs-region"        = var.aws_region
        }
      }
    },
    {
      name              = var.ecs_container_name
      image             = var.ecr_image_url
      cpuReservation    = 256
      memoryReservation = 512
      command           = var.command # default []
      essential         = true
      mountPoints = [
        {
          "sourceVolume" : "hello-observability-log",
          "containerPath" : "/tmp/hello-observability",
          "readOnly" : false
        },
        {
          "sourceVolume" : "access-log",
          "containerPath" : "/tmp/access-log",
          "readOnly" : false
        }
      ]
      environment = [
        {
          "name" : "JAVA_TOOL_OPTIONS",
          "value" : "-javaagent:./opentelemetry-javaagent.jar"
        },
        {
          "name" : "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT",
          "value" : "http://agent:4317"
        },
        {
          "name" : "OTEL_SERVICE_NAME",
          "value" : "hello-observability"
        },
        {
          "name" : "OTEL_TRACES_EXPORTER",
          "value" : "otlp"
        }
      ]
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.host_port
          protocol      = var.protocol
        }
      ],
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "dv-grafana-traces",
          "awslogs-stream-prefix" = "java-springboot-dv-grafana-traces",
          "awslogs-region"        = var.aws_region
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ecs-service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.ecs_cluster.name
  task_definition = aws_ecs_task_definition.ecs-task.arn
  desired_count   = var.desired_count
}