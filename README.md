:

🛒 Retail Store Microservices Platform
AWS EKS with GitOps & Infrastructure as Code
📌 Overview

This project demonstrates a production-grade microservices architecture deployed on AWS using modern DevOps practices including Infrastructure as Code (IaC) and GitOps.

The platform simulates a retail store system composed of multiple services (cart, catalog, orders, checkout, UI), fully automated from infrastructure provisioning to application deployment.

🚀 Key Features
⚙️ Infrastructure as Code (IaC) using Terraform
☁️ Kubernetes deployment on AWS EKS
🔄 GitOps-based continuous delivery using ArgoCD
🐳 Automated CI/CD pipelines with GitHub Actions
🔐 Secure authentication via IAM OIDC (no static credentials)
📦 Containerized microservices using Docker
📊 Helm-based Kubernetes deployments
🏗️ Architecture

The system follows a multi-tier microservices architecture:

Frontend (UI Service)
Backend Services:
Cart Service
Catalog Service
Orders Service
Checkout Service
Container Registry: Amazon ECR
Orchestration: Kubernetes (EKS)
Deployment Strategy: GitOps via ArgoCD
🔄 CI/CD & GitOps Workflow
CI Pipeline (GitHub Actions)
Triggered on code push
Builds Docker images for all microservices
Pushes images to Amazon ECR
Updates Helm chart values (image tags)
CD Pipeline (ArgoCD)
Monitors Git repository for changes
Detects updated Helm values
Automatically syncs and deploys to EKS
🔐 Security
Uses IAM OIDC Federation for GitHub Actions
Eliminates need for static AWS credentials
Ensures secure, short-lived authentication
🧰 Tech Stack
Cloud: AWS (EKS, ECR, IAM, VPC)
Infrastructure: Terraform
CI/CD: GitHub Actions
GitOps: ArgoCD
Containerization: Docker
Orchestration: Kubernetes
Packaging: Helm
Languages: Go, Java, Python
📂 Repository Structure
.
├── terraform/              # Infrastructure as Code (EKS, VPC, IAM, ECR)
├── .github/workflows/     # CI/CD pipelines (GitHub Actions)
├── helm/                  # Helm charts for microservices
├── services/              # Application source code
│   ├── cart/
│   ├── catalog/
│   ├── orders/
│   ├── checkout/
│   └── ui/
└── argocd/                # ArgoCD application manifests
⚡ Getting Started
1. Clone the Repository
git clone https://github.com/Shazil91/retail-store-sample-app.git
cd retail-store-sample-app
2. Provision Infrastructure
cd terraform
terraform init
terraform apply
3. Configure Kubernetes Access
aws eks update-kubeconfig --region <region> --name <cluster-name>
4. Deploy ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f <argocd-install-manifest>
5. Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8001:80
📸 Demo Flow
Push code to GitHub
GitHub Actions builds & pushes Docker images
Helm values updated automatically
ArgoCD detects changes
Application syncs to EKS cluster
🎯 Learning Outcomes
End-to-end DevOps pipeline implementation
GitOps workflow in real-world systems
Secure cloud authentication using OIDC
Kubernetes production deployment strategies
Multi-language microservices orchestration
🔗 GitHub Repository

👉 https://github.com/Shazil91/retail-store-sample-app

👨‍💻 Author

Shazil Ali
DevOps & Agentic AI Engineer
