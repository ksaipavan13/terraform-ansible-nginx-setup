resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # This allows SSH from any IP address. For more security, replace with your specific IP.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0ae8f15ae66fe8cda"
  instance_type = "t3.medium"
  key_name      = "hopp"

  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "Ansible-Managed-Server"
  }

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > hosts.txt"
  }
  provisioner "local-exec" {
  command = "sleep 60"
}
  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i hosts.txt playbook.yml --private-key=/Users/saipavankarepe/Downloads/hopp.pem -u ec2-user -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'
    EOT
  }
}


