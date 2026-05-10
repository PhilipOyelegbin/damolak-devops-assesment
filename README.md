# Damolak DevOps Assessment - MuchToDo API

This repository contains the infrastructure and delivery pipeline for the MuchToDo API, a Go backend deployed on AWS. The current setup is intentionally small but production-oriented: a single EC2 host in a secured VPC, ECR for container images, SSM for access, and CloudWatch for observability.

---

## Architecture Overview

### What is deployed

- `app/MuchToDo` is the Go application.
- `app/MuchToDo/Dockerfile` builds the API into a container image.
- `infra/modules/container` creates the ECR repository used by CI/CD.
- `infra/modules/network` creates the VPC, public/private subnets, NAT gateway, security group, and VPC Flow Logs.
- `infra/modules/instance` creates the EC2 host, IAM role, instance profile, encrypted root volume, and user data bootstrap.
- `infra/modules/monitoring` creates CloudWatch dashboards, alarms, log groups, and SNS notifications.
- `infra/environments/staging` and `infra/environments/production` wire the modules together.
- `.github/workflows/infra.yml` deploy remote state, plan, validate, and deploys the staging/production infrastructure.
- `.github/workflows/app.yml` tests, builds, pushes, and deploys the backend.

### Runtime flow

```text
GitHub push / pull request
  -> GitHub Actions
  -> Deploy remote state
  -> Plan staging environment
  -> Deploy staging environment
  -> Plan production environment
  -> Deploy production environment
  -> Golang app tests and build
  -> Docker image build from app/MuchToDo/Dockerfile
  -> Push image to AWS ECR
  -> Deploy to EC2 staging/production via AWS Systems Manager and save output data to github secret
  -> EC2 pulls image from ECR and runs the container
  -> Logs and metrics go to CloudWatch
```

### Infrastructure layout

- VPC CIDR is environment-specific and subnet sizing is calculated dynamically.
- Public subnets host the EC2 instance and NAT gateway.
- Private subnets are kept for future services such as databases or caches.
- VPC Flow Logs are enabled for network visibility and security auditing.
- The EC2 instance is accessed through SSM, not SSH.
- The EC2 role can read from ECR and publish logs to CloudWatch.
- CloudWatch alarms monitor CPU and instance health and notify through SNS.

---

## Deployment Steps

### 1. Prerequisites

- AWS account with permission to manage EC2, VPC, IAM, ECR, CloudWatch, SNS, and S3 backend resources.
- Terraform installed locally.
- AWS CLI configured with credentials and region.
- GitHub repository secrets configured for the pipeline.

> PS: Ensure you add the `GH_PAT` variable with appropriate permissions before deployment

### 2. Deploy the remote state stack

The Terraform state is stored remotely. Deploy the remote-state infrastructure first, then point each environment backend at the resulting S3 bucket.

```bash
./script/deploy-infra.sh remote
```

### 3. Deploy staging infrastructure

```bash
./script/deploy-infra.sh staging
```

This creates the staging VPC, EC2 instance, monitoring resources, and ECR repository.

### 4. Deploy production infrastructure

```bash
./script/deploy-infra.sh production
```

This creates the production VPC, EC2 instance, monitoring resources, and ECR repository.

### 5. Configure GitHub Actions secrets

Set the following repository secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `GH_PAT`
- `ECR_REPOSITORY_STAGING`
- `ECR_REPOSITORY_PRODUCTION`
- `STAGING_INSTANCE_ID`
- `PRODUCTION_INSTANCE_ID`
- `STAGING_ENV_FILE`
- `PRODUCTION_ENV_FILE`
- `STAGING_INSTANCE_IP`
- `PRODUCTION_INSTANCE_IP`

### 6. Release the infrastcurture/application

- Merge to `infra/remote` to deploy the remote state infrastructure.
- Open a pull request to `infra/staging` to validate, and plan the staging environment.
- Merge to `infra/staging` to deploy the staging environment.
- Open a pull request to `infra/production` to validate, and plan the production environment.
- Merge to `infra/production` to deploy the production environment.
- Open a pull request to `dev` to run tests, and a Go build.
- Merge to `staging` to build the container, push it to ECR, and deploy it to the staging EC2 host via SSM.
- Merge to `main` to repeat the same flow for production.

### 7. Update runtime configuration

The application reads configuration from environment variables. The deployment workflow writes the `.env` content to the host and runs the container with that file mounted into the runtime.

---

## Design Decisions

### 1. EC2 plus Docker instead of ECS

The system uses one EC2 instance per environment because the application is simple, the operational footprint is small, and the assessment is focused on secure infrastructure rather than orchestration depth. ECS or EKS would be the better long-term choice for horizontal scaling, but they would add complexity that is not required for this scope.

### 2. SSM instead of SSH

Access happens through AWS Systems Manager Session Manager so there is no inbound SSH port to manage, no key distribution problem, and access is fully IAM-controlled and auditable.

### 3. ECR instead of Docker Hub

Images are stored in ECR because it keeps the pipeline inside AWS, avoids rate limits and public registry exposure, and allows the EC2 instance to pull images using its IAM role.

### 4. Separate container module

The `infra/modules/container` module exists only to manage the ECR repository. That keeps image registry concerns isolated from network, compute, and monitoring concerns and makes the repository name reusable from both Terraform outputs and the deployment pipeline.

### 5. VPC Flow Logs and CloudWatch

VPC Flow Logs are enabled to give visibility into traffic patterns and provide a basic security audit trail. CloudWatch is used for logs, dashboards, and alarms because it is native to AWS and does not require extra infrastructure.

### 6. Dynamic subnet sizing

Subnet CIDRs are calculated from the VPC CIDR instead of being hardcoded. This avoids invalid subnet ranges when the environment VPC is smaller than expected and makes the module reusable across environments.

### 7. IMDSv2 and encrypted storage

The EC2 instance requires IMDSv2 and uses an encrypted root disk. These are low-cost hardening measures that reduce the impact of metadata abuse and data-at-rest exposure.

---

## Assumptions Made

- The application runs as a single backend service and listens on port `8080` inside the container.
- MongoDB, Redis, and other external dependencies are managed outside this Terraform stack.
- Staging and production use the same codebase but different secrets and AWS resources.
- The pipeline has permission to push to ECR and send SSM commands to the instance.
- The environment file values can be provided safely through GitHub secrets.
- The application can start successfully when its environment variables are provided at runtime.

---

## Limitations or Improvements

### Current limitations

- Only one EC2 instance is deployed per environment, so there is no horizontal failover.
- The database layer is not provisioned here.
- The pipeline relies on GitHub secrets for environment-specific runtime values.
- There is no blue-green or canary deployment strategy.
- CloudWatch alerting is basic and currently centered on CPU and instance health.

### Possible improvements

- Add an Application Load Balancer and Auto Scaling Group for high availability.
- Move environment secrets to AWS Secrets Manager or Parameter Store.
- Add database provisioning or connect the app to a managed database service.
- Add container image lifecycle cleanup and vulnerability reporting in ECR.
- Add automatic rollback if health checks fail.
- Add AWS WAF or rate limiting for exposed public services.

---

## Notes on the CI/CD Pipeline

The workflow in `.github/workflows/app.yml` is aligned with the Go backend and the ECR-based deployment model.

- Pull requests to `dev` run unit tests, and a build.
- Staging pushes build and publish the Docker image, then deploy by SSM.
- Production pushes repeat the same flow with production secrets and instance ID.

---

## Repository Layout

```
damolak-devops-assesment/
├── .github/
│   └── workflows/
│       ├── app.yml                 # CI/CD pipeline for MuchToDo API
│       └── infra.yml               # CI/CD pipeline for Infrastructure
├── app/
│   ├── MuchToDo/
│   │   ├── cmd/api/main.go         # Application entry point
│   │   ├── internal/               # Internal packages (config, handlers, db, etc.)
│   │   ├── go.mod                  # Go module definition
│   │   ├── go.sum                  # Go dependencies lock file
│   │   ├── Dockerfile              # Multi-stage Docker build
│   │   └── Makefile                # Local development targets
│   └── README.md                   # Application documentation
├── infra/
│   ├── modules/
│   │   ├── network/                # VPC, subnets, security groups, flow logs
│   │   ├── instance/               # EC2, IAM, CloudWatch setup
│   │   ├── monitoring/             # CloudWatch dashboards, alarms, SNS
│   │   └── container/              # ECR
│   └── environments/
│       ├── staging/
│       │   ├── main.tf             # Staging module instantiation
│       │   ├── variables.tf        # Staging variables
│       │   ├── outputs.tf          # Staging outputs
│       │   ├── terraform.tfvars    # Staging configuration
│       │   └── provider.tf         # Staging provider configuration
│       └── production/             # Production identical to staging
├── script/
│   ├── deploy-infra.sh             # Helper script for infrastructure deployment
│   └── destroy-infra.sh            # Helper script for infrastructure teardown
└── README.md                       # This file
```

---

## Deployment Summary

1. Deploy remote state.
2. Deploy the staging or production environment with Terraform.
3. Push code to the relevant branch.
4. GitHub Actions builds the Go app into a container.
5. The image is pushed to ECR.
6. SSM runs the remote deployment script on EC2.
7. CloudWatch captures logs and alarms.
8. The application is accessible via `http://<server-ip>/swagger/index.html`

---
