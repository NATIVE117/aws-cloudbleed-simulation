provider "aws" {
  region = "us-east-1"
}

# 1. This tells Terraform to FIND the latest Ubuntu 24.04 AMI automatically
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (the creators of Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# 2. Update your instance to use the dynamic ID and the IAM Profile
resource "aws_instance" "victim_vm" {
  ami           = data.aws_ami.ubuntu.id  # Use the ID found above
  instance_type = "t3.micro"
  key_name      = aws_key_pair.deployer.key_name
  
  # This attaches the IAM Role we created earlier
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # Ensure these match your specific network setup
  subnet_id              = aws_subnet.workload.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "CloudBleed-Victim"
  }
}

# 1. The Network (VPC)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "CloudBleed-VPC" }
}

# 2. The Gateway (Internet Access)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# 3. The Subnet (Publicly Accessible)
resource "aws_subnet" "workload" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "Workload-Subnet" }
}

# 4. Route Table (Connects Subnet to Internet)
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.workload.id
  route_table_id = aws_route_table.rt.id
}

# 5. Security Group (The Firewall)
resource "aws_security_group" "allow_ssh" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.main.id

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

# 6. Upload your Key Pair
resource "aws_key_pair" "deployer" {
  key_name   = "cloudbleed-key"
  public_key = file("cloudbleed_key.pub")
}

# 1. Create the Secret Vault
resource "aws_secretsmanager_secret" "cloudbleed_secret" {
  name        = "production/cloudbleed/token"
  description = "Sensitive token for memory leak simulation"
}

resource "aws_secretsmanager_secret_version" "token_value" {
  secret_id     = aws_secretsmanager_secret.cloudbleed_secret.id
  secret_string = "PROD_TOKEN_XYZ_123456789"
}

# 2. Create the IAM Identity (The Permission Bridge)
resource "aws_iam_role" "ec2_secrets_role" {
  name = "EC2SecretsAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# 3. Define WHAT the role can do (Read the specific secret)
resource "aws_iam_role_policy" "secrets_read_policy" {
  name = "SecretsReadPolicy"
  role = aws_iam_role.ec2_secrets_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "secretsmanager:GetSecretValue"
      Effect   = "Allow"
      Resource = aws_secretsmanager_secret.cloudbleed_secret.arn
    }]
  })
}

# 4. Create the "ID Badge" (Instance Profile)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2SecretsProfile"
  role = aws_iam_role.ec2_secrets_role.name
}

# 5. ATTACH the badge to your VM (Update your existing aws_instance block)
# Inside your existing aws_instance "victim_vm" block, add this line:
# iam_instance_profile = aws_iam_instance_profile.ec2_profile.name