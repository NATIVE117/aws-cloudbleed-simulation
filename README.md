# AWS CloudBleed Simulation & Memory Forensics Lab

## 🎯 Overview
This project simulates a **CloudBleed-style vulnerability**, demonstrating how sensitive data (like API tokens) can "bleed" into a web server's raw RAM. 

Even when using industry-standard tools like **AWS Secrets Manager**, a software-level memory leak can expose plaintext secrets. This lab covers the deployment of secure infrastructure via **Terraform** and the forensic techniques required to hunt for leaked data using **GDB**.

## 🚀 Key Technical Features
* **Infrastructure as Code (IaC):** Automated VPC, Subnet, and EC2 deployment using Terraform.
* **IAM Instance Profiles:** Implementation of the **Principle of Least Privilege** (PoLP) using IAM Roles instead of static Access Keys.
* **Secret Management:** Programmatic retrieval of secrets from AWS Secrets Manager using the AWS CLI v2.
* **Memory Forensics:** Live process debugging and heap analysis of Nginx worker processes.

## 🏗️ Architecture
1. **AWS Secrets Manager** stores a simulated production token.
2. **EC2 Instance** (Ubuntu 24.04) assumes an **IAM Role** to fetch the secret.
3. **Nginx** serves a page that inadvertently loads the secret into its active memory buffers.
4. **GDB** is used to scan the Nginx process memory for the "bleeding" pattern.

## 🕵️ Forensic Workflow
To replicate the forensics performed in this project:
1. **Identify Target Workers:** ```bash
   ps aux | grep nginx
