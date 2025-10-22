# Terraform EKS Jump Server with CloudWatch Monitoring - POC Documentation

## 📋 Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Project Structure](#project-structure)
5. [Component Breakdown](#component-breakdown)
6. [Deployment Steps](#deployment-steps)
7. [Testing & Monitoring](#testing--monitoring)
8. [Troubleshooting](#troubleshooting)
9. [Cleanup](#cleanup)

## 🎯 Overview

This Terraform project creates a complete AWS EKS (Elastic Kubernetes Service) infrastructure with:
- **Jump Server**: EC2 instance for secure cluster access
- **EKS Cluster**: Managed Kubernetes cluster in private subnets
- **CloudWatch Monitoring**: Automated alerts for cluster health
- **Testing Suite**: Stress tests to validate monitoring

### What You'll Learn
- Terraform modular architecture
- AWS EKS cluster setup
- VPC networking for Kubernetes
- CloudWatch monitoring and alerting
- Infrastructure as Code best practices

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
├─────────────────────────────────────────────────────────────┤
│  VPC (10.0.0.0/16)                                        │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │ Public Subnet   │    │ Private Subnets                 │ │
│  │ (10.0.1.0/24)   │    │ (10.0.10.0/24, 10.0.20.0/24)  │ │
│  │                 │    │                                 │ │
│  │ ┌─────────────┐ │    │ ┌─────────────────────────────┐ │ │
│  │ │Jump Server  │ │    │ │      EKS Cluster            │ │ │
│  │ │(EC2)        │ │    │ │  ┌─────────┐ ┌─────────┐    │ │ │
│  │ │- kubectl    │ │    │ │  │ Node 1  │ │ Node 2  │    │ │ │
│  │ │- AWS CLI    │ │    │ │  │         │ │         │    │ │ │
│  │ │- Jenkins    │ │    │ │  └─────────┘ └─────────┘    │ │ │
│  │ └─────────────┘ │    │ └─────────────────────────────┘ │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
│           │                           │                     │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │Internet Gateway │    │        NAT Gateway              │ │
│  └─────────────────┘    └─────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                  ┌─────────────────┐
                  │   CloudWatch    │
                  │   Monitoring    │
                  │   & Alerts      │
                  └─────────────────┘
```

## 📋 Prerequisites

### Required Tools
```bash
# Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
```

### AWS Setup
1. **AWS Account** with appropriate permissions
2. **AWS CLI configured** with credentials
3. **S3 Bucket** for Terraform state: `terra-jenkins-eks1`
4. **Key Pair** named `demo-eks` in AWS EC2

### Create S3 Bucket
```bash
aws s3api create-bucket --bucket terra-jenkins-eks1 --region us-east-1
```

## 📁 Project Structure

```
terra-jump-serv-eks-cw/
├── backend.tf              # Terraform state configuration
├── main.tf                 # Main module orchestration
├── provider.tf             # AWS provider configuration
├── variable.tf             # Global variables
├── outputs.tf              # Output values
├── vpc/                    # VPC module
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── iam/                    # IAM roles module
├── ec2/                    # Jump server module
├── eks/                    # EKS cluster module
├── launch_template/        # Node group template
├── cloudwatch/             # Monitoring module
└── stress-test/            # Testing manifests
    ├── cpu-stress.yaml
    ├── memory-stress.yaml
    └── restart-test.yaml
```

## 🔧 Component Breakdown

### 1. Backend Configuration (`backend.tf`)
```hcl
terraform {
  backend "s3" {
    bucket = "terra-jenkins-eks1"
    key    = "jump-server/terraform.tfstate"
    region = "us-east-1"
    profile = "default"
  }
}
```
**Purpose**: Stores Terraform state remotely in S3 for team collaboration and state locking.

### 2. VPC Module (`vpc/main.tf`)
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  
  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
}
```
**Key Features**:
- **Public Subnet**: For jump server with internet access
- **Private Subnets**: For EKS nodes (security best practice)
- **NAT Gateway**: Allows private resources to access internet
- **DNS Support**: Required for EKS cluster communication

### 3. IAM Module (`iam/main.tf`)
Creates essential roles:

#### EKS Cluster Role
```hcl
resource "aws_iam_role" "eks_cluster_role" {
  name = "demo-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
```

#### EKS Node Role
```hcl
resource "aws_iam_role" "eks_node_role" {
  name = "demo-eks-node-role"
  # Attached policies:
  # - AmazonEKSWorkerNodePolicy
  # - AmazonEKS_CNI_Policy
  # - AmazonEC2ContainerRegistryReadOnly
  # - CloudWatchAgentServerPolicy
}
```

### 4. Jump Server Module (`ec2/main.tf`)
```hcl
resource "aws_instance" "this" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.small"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/userdata.sh")
}
```

**Installed Software** (via userdata.sh):
- AWS CLI v2
- kubectl
- Docker
- Jenkins
- Terraform
- Git

### 5. EKS Module (`eks/main.tf`)
```hcl
resource "aws_eks_cluster" "this" {
  name     = "demo-eks"
  role_arn = var.cluster_iam_role_arn
  version  = "1.33"
  
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false  # Security: Private only
  }
}
```

**Key Features**:
- **Private API Endpoint**: Cluster only accessible from VPC
- **Managed Node Group**: Auto-scaling worker nodes
- **Essential Add-ons**: VPC-CNI, CoreDNS, kube-proxy, CloudWatch

### 6. CloudWatch Module (`cloudwatch/main.tf`)
Creates monitoring for:

#### CPU Utilization Alarm
```hcl
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "demo-eks-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "50"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
}
```

#### Memory Utilization Alarm
```hcl
resource "aws_cloudwatch_metric_alarm" "node_memory_high" {
  alarm_name          = "demo-eks-node-memory-high"
  threshold           = "50"
  metric_name         = "node_memory_utilization"
}
```

#### Pod Restart Alarm
```hcl
resource "aws_cloudwatch_metric_alarm" "pod_restart_high" {
  alarm_name          = "demo-eks-pod-restarts-high"
  threshold           = "5"
  metric_name         = "pod_number_of_container_restarts"
}
```

## 🚀 Deployment Steps

### Step 1: Initialize Terraform
```bash
cd terra-jump-serv-eks-cw
terraform init
```

### Step 2: Plan Deployment
```bash
terraform plan
```
**Review**: Check all resources to be created

### Step 3: Apply Configuration
```bash
terraform apply
```
**Time**: ~15-20 minutes for complete deployment

### Step 4: Verify Deployment
```bash
# Check EKS cluster
aws eks describe-cluster --name demo-eks

# Get jump server IP
terraform output
```

## 🧪 Testing & Monitoring

### Connect to Jump Server
```bash
# SSH to jump server
ssh -i demo-eks.pem ec2-user@<JUMP_SERVER_IP>

# Configure kubectl
aws eks update-kubeconfig --name demo-eks --region us-east-1
```

### Run Stress Tests
```bash
# Apply all stress tests
kubectl apply -f stress-test/

# Monitor pods
kubectl get pods -w

# Check resource usage
kubectl top nodes
kubectl top pods
```

### Test Scenarios

#### 1. CPU Stress Test (`cpu-stress.yaml`)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cpu-stress
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2", "--timeout", "300s"]
```
**Expected**: Triggers CPU > 50% alarm

#### 2. Memory Stress Test (`memory-stress.yaml`)
```yaml
spec:
  template:
    spec:
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "400M", "--timeout", "300s"]
```
**Expected**: Triggers Memory > 50% alarm

### Monitor Alerts
1. **CloudWatch Console**: Check alarm states
2. **Email Notifications**: Sent to `techieegale@gmail.com`
3. **SNS Topic**: `demo-eks-alerts`

## 🔍 Troubleshooting

### Common Issues

#### 1. EKS Cluster Access Denied
```bash
# Update kubeconfig
aws eks update-kubeconfig --name demo-eks --region us-east-1

# Check IAM permissions
aws sts get-caller-identity
```

#### 2. Nodes Not Joining Cluster
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name demo-eks --nodegroup-name demo-eks-node-group

# Verify security groups
aws ec2 describe-security-groups --group-ids <SECURITY_GROUP_ID>
```

#### 3. CloudWatch Metrics Missing
```bash
# Verify CloudWatch addon
kubectl get pods -n amazon-cloudwatch

# Check Container Insights
aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights
```

### Debug Commands
```bash
# Check cluster status
kubectl cluster-info

# View events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check node status
kubectl describe nodes

# View pod logs
kubectl logs -f deployment/cpu-stress
```

## 🧹 Cleanup

### Remove Test Workloads
```bash
kubectl delete -f stress-test/
```

### Destroy Infrastructure
```bash
terraform destroy
```
**Warning**: This will delete all resources and cannot be undone.

### Manual Cleanup (if needed)
```bash
# Delete EKS cluster manually
aws eks delete-cluster --name demo-eks

# Delete VPC endpoints
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<VPC_ID>
```

## 📚 Learning Outcomes

After completing this POC, L1 team members will understand:

1. **Terraform Modules**: How to structure reusable infrastructure code
2. **AWS EKS**: Managed Kubernetes service setup and configuration
3. **VPC Networking**: Public/private subnet architecture for security
4. **IAM Roles**: Service-linked roles for AWS services
5. **CloudWatch Monitoring**: Automated alerting and observability
6. **Infrastructure Testing**: Validating infrastructure with stress tests
7. **Security Best Practices**: Private clusters, least privilege access

## 🎯 Next Steps

1. **Customize Variables**: Modify `variable.tf` for different environments
2. **Add More Monitoring**: Extend CloudWatch alarms for additional metrics
3. **Implement GitOps**: Use ArgoCD or Flux for application deployment
4. **Add Security Scanning**: Integrate security tools like Falco or Twistlock
5. **Multi-Environment**: Create dev/staging/prod variations

## 📞 Support

For questions or issues:
1. Check AWS CloudWatch logs
2. Review Terraform state: `terraform show`
3. Validate AWS permissions
4. Consult AWS EKS documentation

---
**Created for L1 Team Training** | **Version 1.0** | **Date: $(date)**