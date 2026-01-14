#!/bin/bash
# Install Forensics Tools
sudo apt update && sudo apt install gdb unzip -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Fetch and Load Secret (The "Bleed" setup)
MY_SECRET=$(aws secretsmanager get-secret-value --secret-id production/cloudbleed/token --region us-east-1 --query SecretString --output text)
echo "Welcome. Secret loaded: $MY_SECRET" | sudo tee /var/www/html/index.html
