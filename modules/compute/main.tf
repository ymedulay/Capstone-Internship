#compute: bastion, autoscaling, launch templates, cloudwatch

# --- DATA SOURCE FOR AMI ---
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = [var.instance_config["owner"]]
  filter { 
  name = "name"
  values = [var.instance_config["ami_ptr"]] 
}
}

# --- BASTION HOST ---
resource "aws_instance" "bastion" { #single entry point into the private VPC 
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_config["bastion"] #uses t2.micro
  subnet_id              = var.public_subnet_id #placed in a public subnet for external access
  vpc_security_group_ids = [var.bastion_sg_id] #restricted by vpn ip
  key_name               = var.instance_config["key"]
  tags                   = merge(var.common_tags, { Name = "${var.name_prefix}-BastionHost" })
}

# --- Launch Templates ---
#acts as the blueprint for instances created by the ASG
resource "aws_launch_template" "frontend_lt" {
  name                   = "${var.name_prefix}-FrontendLT"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_config["asg"] #uses t3.micro
  vpc_security_group_ids = [var.frontend_sg_id] #places in private security group
  key_name               = var.instance_config["key"]
  #req 2 -> injects the frontend_userdata.sh script to config the server on launch
  user_data              = base64encode(templatefile("${path.root}/scripts/frontend_userdata.sh", { 
    BACKEND_URL = var.backend_lb_dns 
    }))
  
  lifecycle { #tells tf to create a new version of the launch template before attempting to delete 
    create_before_destroy = true #prevents downtime
  }

  monitoring { #ASG can react faster to traffic spikes
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.common_tags, { Name = "${var.name_prefix}-FrontendInstance" })
  }
}

resource "aws_launch_template" "backend_lt" {
  name                   = "${var.name_prefix}-BackendLT"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_config["asg"]
  vpc_security_group_ids = [var.backend_sg_id]
  key_name               = var.instance_config["key"]
  user_data              = base64encode(file("${path.root}/scripts/backend_userdata.sh"))

  lifecycle {  
    create_before_destroy = true
  }

  monitoring { 
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.common_tags, { Name = "${var.name_prefix}-BackendInstance" })
  }
}

# --- Auto Scaling Groups ---
# manages the instances, ensuring high availability and automatic replacement
resource "aws_autoscaling_group" "frontend_asg" {
  # req 3 -> configures ASG capacity (min 2, desired 2, max 4)
  name                = "${var.name_prefix}-FrontendASG"
  max_size            = var.asg_settings["max"] #4
  min_size            = var.asg_settings["min"] #2
  desired_capacity    = var.asg_settings["desired"] #2
  vpc_zone_identifier = var.private_subnet_ids #spreads instances across private AZs
  target_group_arns   = [var.frontend_tg_arn] #connects to the Application Load Balancer
  #ALB decides if instance is healthy -> ASG replaces unhealthy ones
  health_check_type   = var.asg_settings["hc_type"] #ensures replacement if ALB says unhealthy
  
  #time allowed for startup before checking health
  health_check_grace_period = 60

  #enables rolling updates for zero downtime
  instance_refresh {
    strategy = var.instance_refresh_config.strategy
    preferences {
      min_healthy_percentage = var.instance_refresh_config.min_healthy_percentage
      instance_warmup = var.instance_refresh_config.warmup
    }
    triggers = ["vpc_zone_identifier", "tag", "desired_capacity"]
  }

  launch_template { 
    id = aws_launch_template.frontend_lt.id
    version = aws_launch_template.frontend_lt.latest_version
    }
  tag {
    key = "Name"
    value = "${var.name_prefix}-FrontendASG"
    propagate_at_launch = true #ensures instances get the correct Name tag
  }
}

resource "aws_autoscaling_group" "backend_asg" {
  name                = "${var.name_prefix}-BackendASG"
  max_size            = var.asg_settings["max"]
  min_size            = var.asg_settings["min"]
  desired_capacity    = var.asg_settings["desired"]
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [var.backend_tg_arn]
  health_check_type   = var.asg_settings["hc_type"]
  health_check_grace_period = 60

  instance_refresh {
    strategy = var.instance_refresh_config.strategy
    preferences {
      min_healthy_percentage = var.instance_refresh_config.min_healthy_percentage
      instance_warmup = var.instance_refresh_config.warmup
    }
    triggers = ["vpc_zone_identifier", "tag", "desired_capacity"]
  }

  launch_template { 
    id = aws_launch_template.backend_lt.id
    version = aws_launch_template.backend_lt.latest_version
    }
  tag {
    key = "Name"
    value = "${var.name_prefix}-BackendASG"
    propagate_at_launch = true
  }
}

# --- Frontend Scaling Policies (High & Low) ---
#automatically adds or remove instances based on CPU usage
resource "aws_autoscaling_policy" "frontend_scale_out" {
  #defines how to scale out
  name                   = "${var.name_prefix}-Frontend-ScaleOut"
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
  adjustment_type        = var.asg_settings["adj_type"]
  scaling_adjustment     = var.asg_settings["scale_out_val"] #1
  policy_type            = var.asg_settings["policy_type"]
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_high" {
  #defines when to scale out
  alarm_name          = "${var.name_prefix}-frontend-cpu-high"
  comparison_operator = var.cw_comparison_operators["scale_out"]
  evaluation_periods  = 1
  #object access -> accesses metric_name from the cw_alarm_config objects
  metric_name         = var.cw_alarm_config["metric_name"] #CPUUtilization
  namespace           = var.cw_alarm_config["namespace"] #AWS/EC2
  period              = var.asg_settings["alarm_period"] #60 seconds
  statistic           = var.asg_settings["alarm_stat"] #Average
  threshold           = var.asg_settings["cpu_high"] #40%
  alarm_actions       = [aws_autoscaling_policy.frontend_scale_out.arn]
  dimensions          = { 
    (var.cw_metric_dimensions)  = aws_autoscaling_group.frontend_asg.name 
    }
}

resource "aws_autoscaling_policy" "frontend_scale_in" {
  #defines how to scale in
  name                   = "${var.name_prefix}-Frontend-ScaleIn"
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name
  adjustment_type        = var.asg_settings["adj_type"]
  scaling_adjustment     = var.asg_settings["scale_in_val"]
  policy_type            = var.asg_settings["policy_type"]
}

resource "aws_cloudwatch_metric_alarm" "frontend_cpu_low" {
  #defines when to scale in
  alarm_name          = "${var.name_prefix}-frontend-cpu-low"
  comparison_operator = var.cw_comparison_operators["scale_in"]
  evaluation_periods  = 1
  metric_name         = var.cw_alarm_config["metric_name"]
  namespace           = var.cw_alarm_config["namespace"]
  period              = var.asg_settings["alarm_period"]
  statistic           = var.asg_settings["alarm_stat"]
  threshold           = var.asg_settings["cpu_low"]
  alarm_actions       = [aws_autoscaling_policy.frontend_scale_in.arn]
  dimensions          = { 
    (var.cw_metric_dimensions) = aws_autoscaling_group.frontend_asg.name 
    }
}

# --- Backend Scaling Policies (High & Low) ---
resource "aws_autoscaling_policy" "backend_scale_out" {
  name                   = "${var.name_prefix}-Backend-ScaleOut"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  adjustment_type        = var.asg_settings["adj_type"]
  scaling_adjustment     = var.asg_settings["scale_out_val"]
  policy_type            = var.asg_settings["policy_type"]
}

resource "aws_cloudwatch_metric_alarm" "backend_cpu_high" {
  alarm_name          = "${var.name_prefix}-backend-cpu-high"
  comparison_operator = var.cw_comparison_operators["scale_out"]
  evaluation_periods  = 1
  metric_name         = var.cw_alarm_config["metric_name"]
  namespace           = var.cw_alarm_config["namespace"]
  period              = var.asg_settings["alarm_period"]
  statistic           = var.asg_settings["alarm_stat"]
  threshold           = var.asg_settings["cpu_high"]
  alarm_actions       = [aws_autoscaling_policy.backend_scale_out.arn]
  dimensions          = { 
    (var.cw_metric_dimensions)  = aws_autoscaling_group.backend_asg.name 
    }
}

resource "aws_autoscaling_policy" "backend_scale_in" {
  name                   = "${var.name_prefix}-Backend-ScaleIn"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  adjustment_type        = var.asg_settings["adj_type"]
  scaling_adjustment     = var.asg_settings["scale_in_val"]
  policy_type            = var.asg_settings["policy_type"]
}

resource "aws_cloudwatch_metric_alarm" "backend_cpu_low" {
  alarm_name          = "${var.name_prefix}-backend-cpu-low"
  comparison_operator = var.cw_comparison_operators["scale_in"]
  evaluation_periods  = 1
  metric_name         = var.cw_alarm_config["metric_name"]
  namespace           = var.cw_alarm_config["namespace"]
  period              = var.asg_settings["alarm_period"]
  statistic           = var.asg_settings["alarm_stat"]
  threshold           = var.asg_settings["cpu_low"]
  alarm_actions       = [aws_autoscaling_policy.backend_scale_in.arn]
  dimensions          = { 
    (var.cw_metric_dimensions)  = aws_autoscaling_group.backend_asg.name 
    }
}

# --- POST-DEPLOYMENT DATA ---
#problem: when using ASG, ec2 instances are created and terminated automatically, specific IP addresses are not known at the time of writng the code
#solution -> data source queries the AWS API after the instances have been launched


#data source -> fetches IP info for instances after they are launched by the ASG
data "aws_instances" "frontend_instances" {
  instance_tags = { #looks for instances with specified tags
    Name = "${var.name_prefix}-FrontendASG"
  }
  instance_state_names = ["running", "pending"] #filtered by state
  depends_on           = [aws_autoscaling_group.frontend_asg] #waits for the ASG to finish launching instances before checking
}

# Fetch the dynamic instances created by the Backend ASG
data "aws_instances" "backend_instances" {
  instance_tags = {
    Name = "${var.name_prefix}-BackendASG"
  }
  instance_state_names = ["running", "pending"]
  depends_on           = [aws_autoscaling_group.backend_asg]
}