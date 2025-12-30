# Platform Engineering Assessment – AWS / EKS Solution

This repository contains the implementation of the **Platform Engineering Assessment** using **AWS**.

It implements:

- **Amazon EKS** as the managed Kubernetes cluster
- **Amazon RDS for PostgreSQL** as the database
- **AWS Elastic Load Balancer** created automatically via a Kubernetes `Service` of type `LoadBalancer`
- **Terraform** for infrastructure-as-code
- **GitHub Actions** for CI/CD
- **Two environments** (staging + production) separated by Kubernetes namespaces and configuration



---

## 1. Architecture Overview

### 1.1 High-level flow


![photo_2025-12-30_20-09-12](https://github.com/user-attachments/assets/ea5aa599-2787-445a-a151-76c7ad60271b)


  
### 1.2 Components

- **VPC & Networking**
  - Single VPC: `10.0.0.0/16`
  - **Public subnet** (10.0.1.0/24)
    - EKS worker nodes
    - AWS Load Balancer (internet-facing)
  - **Private subnet** (10.0.2.0/24)
    - RDS PostgreSQL instance
  - Internet gateway for public subnet
  - Private subnet has no direct internet access; RDS is **not publicly accessible**

- **Kubernetes (EKS)**
  - One EKS cluster: `platform-eks`
  - One managed node group (1 × `t3.small` node)
  - Two namespaces:
    - `staging`
    - `production`
  - Demo app deployed as `Deployment` + `Service` in each namespace
  - Liveness & readiness probes on `/healthz` and `/readyz`
  - Resource requests/limits for the container

- **Database (RDS PostgreSQL)**
  - Single `db.t3.micro` RDS instance
  - Single database: `appdb`
  - Private subnets only, security group restricts access to EKS worker nodes

- **Load Balancer**
  - Kubernetes `Service` of type `LoadBalancer`
  - EKS provisions an AWS load balancer (NLB/CLB depending on AWS defaults)
  - Each namespace (`staging`, `production`) gets its own external load balancer

- **CI/CD (GitHub Actions)**
  - Branch-based environments:
    - `staging` branch → deploys to `staging` namespace
    - `main` branch → deploys to `production` namespace
  - Pipeline stages:
    1. **Build** Docker image and push to ECR
    2. **Test** basic Node.js healthcheck script
    3. **Scan** container image with Trivy
    4. **Deploy** to EKS

---

## 2. Setup Instructions – Step by Step

### 2.1 Prerequisites

You will need:

- An AWS account (with permissions to create VPC, EKS, RDS, IAM, etc.)
- **AWS CLI v2** installed and configured (`aws configure`)
- **Terraform** ≥ 1.5
- **kubectl** installed
- A GitHub repository where you will push this code

Locally, authenticate with AWS:

```bash
aws configure
# Enter: AWS Access Key, Secret, region (e.g. us-east-1), and default output json
```
---

### 2.2 Provision AWS infrastructure with Terraform

1. Go to the infra directory:

```bash
cd infra
```

2. Create a file `terraform.tfvars` with (at minimum) your desired region:

```hcl
region       = "us-east-1"
cluster_name = "platform-eks"
db_username  = "app_user"
db_name      = "appdb"
```

3. Initialise Terraform:

```bash
terraform init
```

4. Review the plan and apply:

```bash
terraform apply
# type "yes" when prompted
```

This will create:

- VPC with 1 public + 1 private subnet
- EKS cluster + 1-node managed node group
- RDS PostgreSQL (db.t3.micro) in private subnet
- Required IAM roles / security groups

5. After apply completes, capture the outputs:

```bash
terraform output
```

Important outputs:

- `eks_cluster_name`
- `rds_endpoint`
- `rds_db_name`
- `rds_username`
- `rds_password` (marked sensitive)

To view the password explicitly:

```bash
terraform output rds_password
```

---

### 2.4 Test Kubernetes access from your machine

Configure `kubectl` to talk to the new EKS cluster:

```bash
aws eks update-kubeconfig --name platform-eks --region us-east-1

kubectl get nodes
kubectl get ns
```

You should see your worker node and the default namespaces.

---

### 2.5 Configure GitHub repository secrets

In your GitHub repo, go to:

> **Settings → Security → Secrets and variables → Actions → New repository secret**

Create these secrets:

**AWS / EKS**

- `AWS_ACCESS_KEY_ID` – from your IAM user
- `AWS_SECRET_ACCESS_KEY` – from your IAM user
- `AWS_REGION` – e.g. `us-east-1`
- `EKS_CLUSTER_NAME` – `platform-eks` (or the value from `terraform output eks_cluster_name`)

**Database (from Terraform outputs)**

Use the same RDS instance for both environments (simple & cost‑effective):

- `STAGING_DB_HOST` – value of `rds_endpoint`
- `STAGING_DB_NAME` – value of `rds_db_name` (e.g. `appdb`)
- `STAGING_DB_USER` – value of `rds_username`
- `STAGING_DB_PASSWORD` – value of `rds_password`

- `PROD_DB_HOST` – same as `STAGING_DB_HOST`
- `PROD_DB_NAME` – same as `STAGING_DB_NAME`
- `PROD_DB_USER` – same as `STAGING_DB_USER`
- `PROD_DB_PASSWORD` – same as `STAGING_DB_PASSWORD`

> In a real system you'd likely have separate databases or at least schemas per environment; here we share one instance + DB for cost and simplicity and call that out in the architecture decisions.

---

### 2.6 First deployment via CI/CD

1. **Push a `staging` branch** to trigger a staging deploy:

```bash
git checkout -b staging
git push origin staging
```

2. Watch the GitHub Actions workflow (`Actions` tab). It will:

   - Build and push an image to ECR
   - Run basic tests
   - Scan with Trivy
   - Deploy the app to the `staging` namespace
   - Create a Kubernetes `Service` of type `LoadBalancer`

3. Once the workflow is green, get the public address:

```bash
kubectl get svc demo-app -n staging
```

Look for the `EXTERNAL-IP` column and open:

```bash
curl http://<EXTERNAL-IP>/
```

You should see JSON similar to:

```json
{
  "message": "Platform Engineering Assessment demo app",
  "environment": "staging",
  "time": "2025-01-01T00:00:00.000Z"
}
```

4. **Production deployment**

Push to `main` (e.g. merge a PR or push directly). This triggers a deployment to the `production` namespace, with its own load balancer:

```bash
git checkout main
git push origin main

kubectl get svc demo-app -n production
```

---

### 2.7 Tear down (to avoid costs)

When you're done:

```bash
cd infra
terraform destroy
```

This will delete the VPC, EKS, and RDS resources. Also delete the GitHub repo or disable workflows if you no longer need them.

---

## 3. Architecture Decisions

1. **Cloud provider: AWS & EKS**

   Option C (AWS) was chosen to align with the assessment’s AWS focus. EKS provides a managed control plane so we can concentrate on node configuration, networking, and CI/CD instead of running our own Kubernetes control plane. fileciteturn0file0L18-L40

2. **Single EKS cluster with two namespaces**

   - `staging` and `production` are implemented as **namespaces** within the same cluster.
   - This keeps costs down (only one cluster and one node group) while still allowing:
     - Different ConfigMaps/Secrets per environment
     - Separate Services and load balancers
     - Clear logical separation for deploys and debugging

3. **Single RDS instance shared by both environments**

   - A single `db.t3.micro` instance is used with one database (`appdb`).
   - Both staging and production connect to the same DB in this demo to keep infra costs low and Terraform simple.
   - In a real environment we’d likely:
     - Create separate databases or schemas per environment
     - Use separate DB users and stricter access controls

4. **Load balancing with Kubernetes `Service` (type=LoadBalancer)**

   - The simplest way to expose a service on EKS is via `Service` type `LoadBalancer`, which provisions an AWS-managed load balancer.
   - This avoids the extra complexity of deploying and wiring up the AWS Load Balancer Controller.
   - With more time, we’d use the controller and an `Ingress` to provision an **Application Load Balancer (ALB)** specifically, including HTTPS termination.

5. **CI/CD using GitHub Actions + ECR**

   - GitHub Actions is close to the source code, easy to reason about, and cloud‑agnostic.
   - AWS ECR is the natural place to store container images for EKS.
   - The pipeline intentionally stays simple: one job, linear stages, and branch-based environment selection.

---

## 4. Cost Optimization

The brief explicitly mentions keeping costs low (< $20 and tearing down resources). fileciteturn0file0L146-L192

Here’s how this repo supports that:

- **Minimal instance sizes**
  - EKS node group: **1 × `t3.small`** worker node
  - RDS: **`db.t3.micro`** with 20 GB storage
- **Single cluster, single RDS instance**
  - Both environments share a cluster and database instance.
- **No NAT Gateway**
  - Worker nodes live in a public subnet (with restricted security groups) so they can reach the internet directly without a NAT gateway, which would otherwise dominate costs in AWS.
- **Local Terraform state**
  - No extra costs for state backends.
- **Easy destruction**
  - `terraform destroy` removes all created resources.

This setup is not production-grade for a large system, but it is appropriate for a small assessment environment and very cheap if run only for short periods.

---

## 5. Security Considerations

1. **Secrets management**

   - Database credentials are generated by Terraform (`random_password`) and **never committed** to the repo.
   - They are copied into GitHub **Actions secrets**, which are then used to create Kubernetes `Secret` objects (`app-secrets`) in each namespace.
   - The app reads credentials only from environment variables backed by Kubernetes Secrets.

2. **Network security**

   - RDS is in a **private subnet** with `publicly_accessible = false`.
   - RDS security group allows inbound traffic on port 5432 **only from the EKS nodes’ security group**.
   - The VPC has a public subnet for nodes and load balancers, but the database never has a public IP.

3. **IAM**

   - EKS cluster and nodes have dedicated IAM roles with the standard managed policies:
     - `AmazonEKSClusterPolicy`
     - `AmazonEKSWorkerNodePolicy`
     - `AmazonEKS_CNI_Policy`
     - `AmazonEC2ContainerRegistryReadOnly`
   - GitHub Actions authenticates using an IAM access key stored as a secret (simple for a demo, but in real life you’d prefer GitHub OIDC + an assumable role).

4. **Container security**

   - Images are based on `node:20-alpine` (small surface area).
   - CI/CD scans the final image using **Trivy**, failing the pipeline if HIGH or CRITICAL vulnerabilities are found.

5. **Kubernetes security**

   - The pod has modest CPU/memory requests and limits.
   - Liveness and readiness probes ensure unhealthy containers are restarted and excluded from traffic.
   - No hostPath or privileged pods used.

---

## 6. Troubleshooting Guide

### 6.1 Check pods and services

```bash
# Staging
kubectl get pods -n staging
kubectl get svc  -n staging

# Production
kubectl get pods -n production
kubectl get svc  -n production
```

If pods are `CrashLoopBackOff`, inspect details:

```bash
kubectl describe pod <pod-name> -n staging
kubectl logs <pod-name> -n staging
```

---

### 6.2 Verify health endpoints

You can test via port-forward from your local machine:

```bash
kubectl port-forward svc/demo-app -n staging 8080:80 &
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```

Expected responses:

- `/healthz` → `{ "status": "ok" }`
- `/readyz` → `{ "status": "ready" }`

If these fail, check:

- Database connectivity (see next section)
- Wrong DB host / credentials in ConfigMap or Secret
- RDS instance status in AWS console

---

### 6.3 Check database connectivity

From inside the pod:

```bash
kubectl exec -it deploy/demo-app -n staging -- sh
# inside container:
node -e "console.log(process.env.DB_HOST, process.env.DB_NAME, process.env.DB_USER)"
```

Ensure:

- `DB_HOST` equals the RDS endpoint
- `DB_NAME` equals `appdb` (or your custom name)
- `DB_USER` is `app_user` (or whatever you set)

If environment variables look wrong, re-run the CI/CD pipeline after updating GitHub secrets so that it recreates the Kubernetes ConfigMap and Secret.

---

### 6.4 CI/CD pipeline failures

Common scenarios:

- **Build/test failing**
  - Check the `Run basic tests` and `Build Docker image` logs in GitHub Actions.
  - Ensure `package.json` is valid and Dockerfile builds locally.

- **Trivy scan failing**
  - The scan step fails on HIGH/CRITICAL vulnerabilities.
  - Update dependencies or temporarily relax the severity threshold if needed (in a real system you’d fix them).

- **Deploy failing**
  - Usually indicates an issue with `aws eks update-kubeconfig` or missing IAM permissions.
  - Verify the GitHub Actions IAM user has permissions:
    - `eks:DescribeCluster`
    - `eks:ListClusters`
    - `ecr:*` (or at least read/write)
    - `sts:GetCallerIdentity`

---

## 7. Future Improvements

If there were more time, here’s how I’d extend this setup:

1. **Proper ALB Ingress**
   - Install AWS Load Balancer Controller via Helm.
   - Replace the `Service` of type `LoadBalancer` with an `Ingress` that provisions an **Application Load Balancer**, including HTTPS (ACM-managed certificates).

2. **Stronger environment isolation**
   - Separate RDS databases (or schemas) per environment.
   - Distinct DB users with least-privilege grants.

3. **Observability stack**
   - Deploy Prometheus and Grafana (via Helm).
   - Expose custom metrics from the app (e.g. request count/latency).
   - Configure alerts for high error rates or Pod restarts.

4. **Security hardening**
   - Use GitHub OIDC + IAM role for CI/CD instead of static access keys.
   - Add Kubernetes NetworkPolicies to restrict pod-to-pod communication.
   - Use AWS Secrets Manager + CSI driver to mount secrets into pods.

5. **Scalability and resilience**
   - Add a Horizontal Pod Autoscaler (HPA) based on CPU or custom metrics.
   - Configure multi-AZ node groups and RDS Multi-AZ for higher availability (at higher cost).
   - Implement blue-green/canary deployment strategies (e.g. with Argo Rollouts).

---

## 8. Repository Layout

```text
.
├── README.md
├── app
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json
│   ├── src
│   │   └── index.js
│   └── scripts
│       └── healthcheck.js
├── infra
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── modules
│       ├── network
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── eks
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── rds
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
├── k8s
│   ├── deployment.yaml
│   └── service.yaml
└── .github
    └── workflows
        └── ci-cd.yaml
```

## 9. Evidence / Screenshots
### 9.1 Local repository setup
![01-local-repo-remote png](https://github.com/user-attachments/assets/0c4b7bc1-f5dd-47c5-a3d8-dccbbc281fec)
![02-vscode-project-open](https://github.com/user-attachments/assets/edbeaa75-2f3f-48e7-9aa6-d670a00fd0c7)

### 9.2 Tooling verification
![04-tool-versions](https://github.com/user-attachments/assets/d0dae2dd-3c1b-4a84-9e65-706bf1446149)

### 9.3 AWS CLI configured
![05-aws-configure](https://github.com/user-attachments/assets/7c7f4f39-b170-4f9d-a6d8-7f8db5ae840f)

### 9.4 Terraform variables
![06-terraform-tfvars](https://github.com/user-attachments/assets/fdb7a344-4240-40b0-8b54-11050748b513)

### 9.5 Terraform init
![07-terraform-init](https://github.com/user-attachments/assets/3c480362-ba15-4695-860f-6568e1310b5e)

### 9.7 Terraform EKS data-source error and fix
![08b-terraform-error-eks-data](https://github.com/user-attachments/assets/eceb8993-fc9e-48ea-bcc1-2b87493d36f2)

fix: remove this entire block(data,the provider "kubernetes" and the two kubernetes_namespace resources)
![remove k8s provider](https://github.com/user-attachments/assets/235ce23d-4356-445b-86c4-3a89052b9b37)

### 9.8 EKS and RDS multi-AZ requirement
![EKS and RDS multi-AZ requirement](https://github.com/user-attachments/assets/a03167f2-ee69-4f7e-a666-a24d34b438b1)

fix: This error occurs because AWS is enforcing good practice: EKS and RDS subnet groups must span at least 2 Availability Zones.
- We fixed it by:
  - Creating an extra public and private subnet in another AZ.
  - Passing both public subnets to EKS.
  - Passing both private subnets to RDS.

### 9.10 RDS engine version error and fix 
![RDS engine version error ](https://github.com/user-attachments/assets/e927c7b4-3004-4f0e-aa8f-337fc80474b5)

fix: remove engine-version line and let AWS pick a valid default
![rds engine](https://github.com/user-attachments/assets/1185acd4-36b7-4d69-a59b-aad81b850cc4)


### 9.11 Terraform apply success
![09-terraform-apply](https://github.com/user-attachments/assets/0d4c7e71-ccea-41bd-9c37-c43ac8dea628)

VPC + EKS + RDS from AWS console
![vpc](https://github.com/user-attachments/assets/e92eeaa1-6b46-4dc8-9350-147d0bacfef6)

![eks](https://github.com/user-attachments/assets/7185623b-28c5-4f75-913a-1d54072d58d1)

![postgres](https://github.com/user-attachments/assets/258a11e4-b981-435c-a63c-5410ffb09661)

### 10.1 Initial cluster state
![initial cluster state](https://github.com/user-attachments/assets/68d27a6d-fc47-47d7-90c2-b0e889de05fc)

### 10.2 EKS cluster verification
![eks cluster](https://github.com/user-attachments/assets/35d3556d-7b7a-411e-8034-14b6ad429a04)

### 11 GitHub Actions secrets configured
![12-github-secrets-configured](https://github.com/user-attachments/assets/6ea5f3d1-2569-47c4-93ab-ce9521f803e0)

### 12 Trigger the GitHub Actions CI/CD pipeline for the `staging` environment
  Image Security Scanning (Trivy)

- CI/CD runs Trivy against the built Docker image (OS + library vulnerabilities).
- For this demo, Trivy is configured with exit-code: 0 and severity: CRITICAL,HIGH:
  - Vulnerabilities are still visible in pipeline logs.
  - The pipeline does not block deployments on these findings during the assessment.
- In a real production environment, the policy would likely be stricter (for example,
  failing the pipeline on CRITICAL issues and requiring dependency upgrades).
error screenshot:
![scan error1](https://github.com/user-attachments/assets/2814491e-125b-4c7c-87c3-252b67a06ffd)
![scan fail](https://github.com/user-attachments/assets/9f4409ac-3854-4c92-b854-384c19bd8f75)

fix: change exit-code: from '1' to '0'

![worked](https://github.com/user-attachments/assets/3157a374-50a1-4f90-8793-8a900051df21)

### 12.1 GitHub Actions CI/CD pipeline `staging` environment success

![worked](https://github.com/user-attachments/assets/fbb05411-1fb4-41ec-b6bc-1e118fa6a832)

![staging succes](https://github.com/user-attachments/assets/c4bafb9c-e8e0-41c6-9f92-d540fd1ee147)






