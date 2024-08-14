provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ami_from_instance" "web_ami" {
  name               = "terraform-ansible"
  source_instance_id = "i-006badb0389e4648d"  # Replace with your current instance ID
  snapshot_without_reboot = true
}

resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-launch-template-"
  image_id      = aws_ami_from_instance.web_ami.id
  instance_type = "t3.micro"
  key_name      = "hopp"

  network_interfaces {
    security_groups = [aws_security_group.allow_ssh.id]
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i hosts.txt playbook.yml --private-key=/Users/saipavankarepe/Downloads/hopp.pem -u ec2-user -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'
    EOT
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Ansible-Managed-Server"
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                 = "web-asg"
  vpc_zone_identifier  = ["subnet-0da373a5ec08a2071"]
  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
}
  min_size             = 1
  max_size             = 1  
  desired_capacity     = 1

  instance_refresh {  
    strategy = "Rolling"
    preferences {
      instance_warmup              = 300
      min_healthy_percentage       = 90
      skip_matching                = false
      standby_instances            = "Ignore"
      scale_in_protected_instances = "Ignore"
    }
  }
  
  tag {
    key                 = "Name"
    value               = "Ansible-Managed-Server"
    propagate_at_launch = true
  }
}

output "ami_id" {
  value = aws_ami_from_instance.web_ami.id
}
  
