# Define the provider
provider "aws" {
  region = "us-east-1"
}

# Security group allowing SSH
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = "vpc-009f8ae4effa297b9"  # Your VPC ID

  ingress {
    description = "SSH"
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

# Step 1: Create and configure an EC2 instance with Ansible
resource "aws_instance" "web_server" {
  ami           = "ami-079f209c2e9a02afd"  # Amazon Linux 2 AMI ID for us-east-1
  instance_type = "t4g.micro"  # Using Graviton instance type
  key_name      = "hopp"  # Your key pair name
  security_groups = [aws_security_group.allow_ssh.name]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 30 && ansible-playbook -i ${self.public_ip}, playbook.yml --private-key=/Users/saipavankarepe/Downloads/hopp.pem -u ec2-user -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'
    EOT
  }

  tags = {
    Name = "Ansible-Configured-Server"
  }
}

# Step 2: Create an AMI from the configured instance
resource "aws_ami_from_instance" "web_ami" {
  name               = "terraform-ansible-configured-ami"
  source_instance_id = aws_instance.web_server.id
  snapshot_without_reboot = true

  tags = {
    Name = "terraform-ansible-configured-ami"
  }
}

# Step 3: Launch template for Auto Scaling using the newly created AMI
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-launch-template"
  image_id      = aws_ami_from_instance.web_ami.id
  instance_type = "t4g.micro"  # Modify as needed
  key_name      = "hopp"  # Your key pair name

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "gp2"
    }
}
  
  network_interfaces {
    associate_public_ip_address = true
    security_groups = [aws_security_group.allow_ssh.id]
    subnet_id = "subnet-0b1710dea004d7cb1"  # Your Subnet ID
  }
   
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "AutoScaledInstance"
    }
  }
}
  
# Step 4: Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity     = 1
  max_size             = 1
  min_size             = 1
  vpc_zone_identifier  = ["subnet-0b1710dea004d7cb1"]  # Your Subnet ID
  
  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = "AutoScaledInstance"
    propagate_at_launch = true
  }
}
output "ami_id" {
  value = aws_ami_from_instance.web_ami.id
}
    
output "launch_template_id" {
  value = aws_launch_template.web_launch_template.id
}  
 

