Project Title Retail Store Microservices Platform — AWS EKS with GitOps & IaC

Description:

Built and deployed a production-grade multi-tier retail application on AWS EKS using a fully automated GitOps pipeline.

Provisioned AWS infrastructure (EKS cluster, VPC, ECR, IAM) using Terraform
Implemented CI/CD with GitHub Actions — automated Docker image builds and ECR pushes for 5 microservices (Go, Java, Python), secured with IAM OIDC federation (no static credentials)
Deployed and configured ArgoCD for GitOps-based continuous delivery — Helm chart values auto-updated on each build triggering automatic sync to EKS
Managed Kubernetes workloads across cart, catalog, orders, checkout, and UI services using Helm charts
Tech Stack: AWS EKS · Terraform · ArgoCD · GitHub Actions · Amazon ECR · Docker · Helm · Kubernetes · IAM OIDC · Go · Java · Python

GitHub: github.com/Shazil91/retail-store-sample-app
