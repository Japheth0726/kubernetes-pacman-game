provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

# RSA key of size 4096 bits
resource "tls_private_key" "keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# creating private key
resource "local_file" "keypair-4" {
  content         = tls_private_key.keypair.private_key_pem
  filename        = "key.pem"
  file_permission = "600"
}
# creating ec2 keypair
resource "aws_key_pair" "keypair" {
  key_name   = "k8s-keypair"
  public_key = tls_private_key.keypair.public_key_openssh
}

# security group for kubernetes
resource "aws_security_group" "k8s-sg" {
  name        = "k8s-sg"
  description = "Allow Inbound Traffic"
  ingress {
    protocol    = "tcp"
    description = "all port"
    from_port   = 0
    to_port     = 65535
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "k8s-sg"
  }
}

# creating Ec2 for master
resource "aws_instance" "master" {
  ami                         = "ami-05134c8ef96964280" //ubuntu
  instance_type               = "t3.medium"
  vpc_security_group_ids      = [aws_security_group.k8s-sg.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data                   = file("./test.sh")
  tags = {
    Name = "master-node"
  }
}

# creating ec2 for worker
resource "aws_instance" "worker" {
  count                       = 2
  ami                         = "ami-05134c8ef96964280" //ubuntu
  instance_type               = "t3.medium"
  vpc_security_group_ids      = [aws_security_group.k8s-sg.id]
  key_name                    = aws_key_pair.keypair.id
  associate_public_ip_address = true
  user_data                   = file("./worker-userdata.sh")
  tags = {
    Name = "worker-node-${count.index}"
  }
}

output "master" {
  value = aws_instance.master.public_ip
}

output "workers" {
  value = aws_instance.worker.*.public_ip
}