# Flagship Capstone — Containerized Web App with Full CI/CD Pipeline

## Overview

A production-style deployment pipeline combining Terraform, Docker, ECR, ECS Fargate, and GitHub Actions. Every push to the `main` branch automatically builds a new Docker image, pushes it to ECR, and redeploys it on AWS ECS — no manual steps required.

---

## Architecture Diagram

![Capstone Architecture](./capstone-architecture.png)

---

## How It Works

```
Developer edits index.html
        ↓
git push → main
        ↓
GitHub Actions detects push (trigger: on push)
        ↓
1. Checkout code
2. Configure AWS credentials (GitHub Secrets)
3. docker build -t my-webpage .
4. docker tag → ECR URI
5. docker push → ECR
6. aws ecs update-service --force-new-deployment
        ↓
ECS pulls new image from ECR
        ↓
Live update at http://<public-ip> in ~30 seconds
```

---

## Tech Stack

| Tool | Purpose |
|---|---|
| **Terraform** | Provisions all 12 AWS resources as code |
| **Docker** | Packages the web app into a container |
| **Amazon ECR** | Stores Docker images (private registry) |
| **Amazon ECS + Fargate** | Runs containers — no EC2 to manage |
| **GitHub Actions** | Automates build, push, and deploy on every commit |

---

## Infrastructure (Terraform)

All AWS resources provisioned with a single `terraform apply`:

```
VPC (10.0.0.0/16)
├── Internet Gateway
├── Public Subnet (10.0.1.0/24) — us-west-1c
├── Route Table → IGW (0.0.0.0/0)
├── Security Group (allow HTTP :80)
├── ECR Repository (my-webpage)
├── IAM Execution Role (ECS → ECR access)
└── ECS Cluster (capstone-cluster)
    ├── Task Definition (0.25 vCPU / 512 MB)
    └── ECS Service (desired: 1, Fargate)
```

---

## Application

A custom nginx web server serving a personalized HTML page:

```dockerfile
FROM nginx
COPY index.html /usr/share/nginx/html/index.html
```

---

## CI/CD Pipeline (GitHub Actions)

**File:** `.github/workflows/deploy.yml`

**Trigger:** Push to `main` branch

```yaml
name: Deploy to ECS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: us-west-1

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Login to ECR
        run: aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin 513410254247.dkr.ecr.us-west-1.amazonaws.com

      - name: Build Docker image
        run: docker build -t my-webpage .

      - name: Tag image
        run: docker tag my-webpage:latest 513410254247.dkr.ecr.us-west-1.amazonaws.com/my-webpage:latest

      - name: Push to ECR
        run: docker push 513410254247.dkr.ecr.us-west-1.amazonaws.com/my-webpage:latest

      - name: Deploy to ECS
        run: aws ecs update-service --cluster capstone-cluster --service capstone-service --force-new-deployment
```

**GitHub Secrets required:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

---

## Setup

### 1. Deploy infrastructure
```bash
terraform init
terraform apply
```

### 2. Push initial Docker image manually
```bash
aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-1.amazonaws.com
docker build -t my-webpage .
docker tag my-webpage:latest <ecr-uri>:latest
docker push <ecr-uri>:latest
```

### 3. Add GitHub Secrets
Go to GitHub repo → Settings → Secrets and variables → Actions → Add:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 4. Push any change — pipeline runs automatically
```bash
git add .
git commit -m "update app"
git push origin main
```

---

## Cleanup

```bash
terraform destroy
```

Destroys all 12 AWS resources cleanly. ECR repository uses `force_delete = true` to remove images automatically.

---

## Key Learnings

- Terraform provisions the entire AWS infrastructure from scratch with one command
- ECR must have an image before ECS can start — always push manually first
- `--force-new-deployment` tells ECS to pull the latest image and restart containers
- GitHub Secrets securely pass AWS credentials without hardcoding them
- The CI/CD pipeline removes all manual deployment steps — push code, it deploys itself
- `force_delete = true` on the ECR resource prevents destroy failures when images exist
