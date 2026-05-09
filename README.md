# Damolak DevOps Assessment - MuchToDo API Infrastructure

A production-ready, secure infrastructure deployment for the **MuchToDo API**, a Go-based task management backend. This repository contains Infrastructure-as-Code (IaC) for AWS, automated CI/CD pipelines, and containerized application deployment.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Deployment Steps](#deployment-steps)
- [Design Decisions](#design-decisions)
- [Assumptions](#assumptions)
- [Limitations & Improvements](#limitations--improvements)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [GitHub Secrets Setup](#github-secrets-setup)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

### High-Level Design

```
┌─────────────────────────────────────────────────────────────────┐
│                         GitHub Actions CI/CD                     │
│  (Secret Scan → Test → Build → Docker Push → EC2 Deploy via SSM) │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │   AWS ECR Registry  │
                    │   (Docker Images)   │
                    └─────────────────────┘
                              ↓
        ┌─────────────────────────────────────────────────┐
        │             AWS VPC (10.8.1.0/24)              │
        │  ┌────────────────────────────────────────┐   │
        │  │  Public Subnet (Tier: Public)          │   │
        │  │  └──────────────────────────────────┐  │   │
        │  │  │ EC2 Instance (t3.micro)         │  │   │
        │  │  │ - Docker Container: muchtodo-api│  │   │
        │  │  │ - Port: 8080 (mapped to 80)     │  │   │
        │  │  │ - IAM: SSM + CloudWatch + ECR   │  │   │
        │  │  │ - Security: Encrypted EBS       │  │   │
        │  │  └──────────────────────────────────┘  │   │
        │  │   ↑ Internet Gateway ↑                 │   │
        │  └────────────────────────────────────────┘   │
        │  ┌────────────────────────────────────────┐   │
        │  │  Private Subnets (Tier: Private)       │   │
        │  │  - Future: RDS, ElastiCache, etc.     │   │
        │  │   ↓ NAT Gateway (HA)                  │   │
        │  └────────────────────────────────────────┘   │
        │                                                 │
        │  ┌────────────────────────────────────────┐   │
        │  │ VPC Flow Logs → CloudWatch            │   │
        │  │ (Network traffic visibility)          │   │
        │  └────────────────────────────────────────┘   │
        └─────────────────────────────────────────────────┘
                              ↓
                ┌─────────────────────────┐
                │   AWS CloudWatch        │
                │ - Metrics & Alarms      │
                │ - Application Logs      │
                │ - SNS Notifications     │
                └─────────────────────────┘
```

### Components

#### 1. **Network Module** (`infra/modules/network/`)

- **VPC**: Custom CIDR block with automatic subnet calculation
- **Multi-AZ Public Subnets**: For internet-facing resources (EC2)
- **Multi-AZ Private Subnets**: For future internal services (databases, caches)
- **NAT Gateway (HA)**: Dual NAT for redundancy, outbound internet access from private subnets
- **Security Group**: Restricts inbound traffic (HTTP/HTTPS only) to the backend
- **VPC Flow Logs**: CloudWatch-integrated network traffic analysis for security auditing

#### 2. **Instance Module** (`infra/modules/instance/`)

- **EC2 Instance (t3.micro)**: Cost-optimized compute for low-traffic staging/production
- **Ubuntu 22.04 LTS**: Hardened, regularly updated OS image
- **IAM Role with Policies**:
  - `AmazonSSMManagedInstanceCore`: Secure shell access via AWS Systems Manager Session Manager
  - `CloudWatchAgentServerPolicy`: Log collection and metrics publishing
  - `AmazonEC2ContainerRegistryReadOnly`: ECR image pulls during deployment
- **Encrypted EBS**: Root volume encryption (KMS) for data at rest
- **Metadata v2 (IMDSv2)**: Hardened IMDS to prevent instance metadata exploits
- **CloudWatch Logs**: Application and system logs collected automatically

#### 3. **Monitoring Module** (`infra/modules/monitoring/`)

- **CloudWatch Dashboards**: Real-time visualization of EC2 CPU, network, and status checks
- **Metric Alarms**: Alerts on high CPU (>80%) or failed status checks
- **SNS Topic**: Centralized alerting; subscriptions for email/Slack/PagerDuty

#### 4. **Remote State Module** (`infra/remote-state/`)

- **S3 Backend**: Terraform state storage (production-ready, remote collaboration)

#### 5. **CI/CD Pipeline** (`.github/workflows/app.yml`)

- **PR to Staging**: Secret scanning, unit tests, Go binary build
- **Merge to Staging**: Docker image build, ECR push, EC2 deployment via SSM Run Command
- **Merge to Main**: Identical build/push, production EC2 deployment

---

## Deployment Steps

### Initial Infrastructure Setup

#### 1. Configure Local Environment

```bash
# Clone the repository
git clone https://github.com/PhilipOyelegbin/damolak-devops-assesment.git
cd damolak-devops-assesment

# Install Terraform (v1.0+)
terraform -version

# Install AWS CLI v2 and configure credentials
aws configure
# Set your AWS access key, secret key, region, and output format (json)
```

#### 2. Initialize Remote State (One-time)

```bash
# Deploy the remote state infrastructure (S3)
./script/deploy-infra.sh remote

# Save the S3 bucket name from outputs
# You'll need these for the next step
```

#### 3. Set Up Terraform Backend for Environments

- Update infra/environments/staging/provider.tf with your S3 bucket
- Replace BUCKET_NAME
- Update the terraform.tfvars with appropriate variables
- Repeat for production

#### 4. Deploy Staging Infrastructure

```bash
./script/deploy-infra.sh staging

# Save outputs (optional)
cd infra/environments/staging
terraform output -json > stagiing-outputs.json
```

#### 5. Deploy Production Infrastructure

```bash
./script/deploy-infra.sh production

# Save outputs (optional)
cd infra/environments/production
terraform output -json > production-outputs.json
```

### Application Deployment via CI/CD

#### 1. Configure GitHub Secrets

Add the following secrets to your GitHub repository (`Settings → Secrets and variables → Actions`):

```
AWS_ACCESS_KEY_ID              # AWS IAM user access key
AWS_SECRET_ACCESS_KEY          # AWS IAM user secret key
AWS_REGION                     # e.g., eu-west-2
ECR_REPOSITORY_BACKEND         # ECR repo name (e.g., muchtodo-backend)
STAGING_INSTANCE_ID            # EC2 instance ID from staging deployment
PRODUCTION_INSTANCE_ID         # EC2 instance ID from production deployment
STAGING_ENV_FILE               # Base64-encoded .env for staging (see below)
PRODUCTION_ENV_FILE            # Base64-encoded .env for production
```

#### 2. Create Environment Files

For each environment, create a `.env` file and encode it as a GitHub secret:

```bash
# Staging environment file content
cat > /tmp/staging.env <<EOF
PORT=8080
MONGO_URI=mongodb://...
DB_NAME=much_todo_db
JWT_SECRET_KEY=your-super-secret-key-staging
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=true
REDIS_ADDR=redis:6379
LOG_LEVEL=INFO
LOG_FORMAT=json
ALLOWED_ORIGINS=https://staging.yourdomain.com,http://localhost:5173
COOKIE_DOMAINS=staging.yourdomain.com
SECURE_COOKIE=true
EOF

# Base64 encode and copy to GitHub secret
cat /tmp/staging.env | base64 -w 0 | xclip -selection clipboard
# Paste into STAGING_ENV_FILE secret
```

#### 3. Deploy via Git Push

```bash
# Feature branch → PR to staging
git checkout -b feature/my-feature
git add .
git commit -m "Add new feature"
git push origin feature/my-feature

# GitHub Actions will:
# - Run secret scanning
# - Execute unit tests
# - Build Go binary
# - Report results in PR

# Merge PR to staging branch
git checkout staging
git merge feature/my-feature --no-ff
git push origin staging

# GitHub Actions will:
# - Build Docker image
# - Push to ECR
# - Deploy to staging EC2 via SSM Run Command

# Merge staging to main for production deployment
git checkout main
git merge staging --no-ff
git push origin main

# GitHub Actions will:
# - Build Docker image
# - Push to ECR
# - Deploy to production EC2 via SSM Run Command
```

### Manual Deployment (Without CI/CD)

```bash
# For emergencies, deploy directly via AWS CLI

# 1. Build and push Docker image manually
cd app/MuchToDo
docker build -t muchtodo-backend:latest .
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin <ECR_REGISTRY>
docker tag muchtodo-backend:latest <ECR_REGISTRY>/muchtodo-backend:latest
docker push <ECR_REGISTRY>/muchtodo-backend:latest

# 2. Deploy to EC2 via SSM
aws ssm send-command \
  --instance-ids "i-1234567890abcdef0" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "#!/bin/bash",
    "set -e",
    "mkdir -p /opt/muchtodo",
    "echo '\''PORT=8080...'\'' > /opt/muchtodo/.env",
    "aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin <ECR_REGISTRY>",
    "docker pull <ECR_REGISTRY>/muchtodo-backend:latest",
    "docker stop muchtodo-api || true",
    "docker rm muchtodo-api || true",
    "docker run -d --name muchtodo-api --restart unless-stopped -p 80:8080 --env-file /opt/muchtodo/.env <ECR_REGISTRY>/muchtodo-backend:latest"
  ]'
```

---

## Design Decisions

### 1. **Multi-AZ High Availability for NAT Gateway**

**Decision**: Enable NAT HA (one NAT per AZ) by default

- **Rationale**: Outbound internet failures become a single point of failure without HA NAT
- **Trade-off**: Doubles NAT costs (~$32/month per extra NAT), but critical for production uptime
- **Override**: Set `enable_nat_high_availability = false` in tfvars for dev/staging to save costs

### 2. **EC2 over ECS/Fargate for Initial Deployment**

**Decision**: Use EC2 with Docker containers

- **Rationale**:
  - Single-server setup keeps infrastructure simple and manageable
  - Easier to manage stateful applications or databases running alongside
  - Better for cost-sensitive staging environments (t3.micro eligible)
- **Future Evolution**: Migrate to ECS Fargate for true serverless container orchestration and auto-scaling

### 3. **SSM Session Manager instead of SSH Keys**

**Decision**: Disable SSH (no key pairs); use AWS Systems Manager Session Manager

- **Rationale**:
  - Eliminates SSH key distribution and rotation overhead
  - Provides IAM-based access control and full audit logging
  - Supports connection through AWS CLI without opening SSH ports (0.0.0.0/22)
  - Integrates with CloudTrail for compliance
- **Caveat**: EC2 must have IAM role with `AmazonSSMManagedInstanceCore` policy (already configured)

### 4. **ECR for Image Registry**

**Decision**: Use AWS ECR instead of Docker Hub

- **Rationale**:
  - Native AWS integration; no external registry to manage
  - Fine-grained IAM access controls for push/pull
  - Private images by default (no accidental public exposure)
  - Automatic image scanning for vulnerabilities
- **Implementation**: IAM role attached to EC2 has `AmazonEC2ContainerRegistryReadOnly` for pulls during deployment

### 5. **VPC Flow Logs for Network Security**

**Decision**: Enable VPC Flow Logs to CloudWatch

- **Rationale**:
  - Visibility into all network traffic (security auditing, troubleshooting)
  - Detects suspicious patterns (DDoS, port scanning, data exfiltration)
  - Required for SOC2/PCI compliance in regulated environments
- **Cost**: ~$0.50/GB ingested (relatively low for security benefit)

### 6. **Encrypted EBS Root Volume**

**Decision**: All EC2 instances have encrypted root volumes (AWS KMS)

- **Rationale**:
  - Protects data at rest against theft or unauthorized access
  - Minimal performance overhead with modern KMS keys
  - Default AWS recommendation (best practice)

### 7. **IMDSv2 Enforcement**

**Decision**: Require IMDSv2 for EC2 instance metadata access

- **Rationale**:
  - IMDSv1 vulnerable to SSRF (Server-Side Request Forgery) attacks
  - Attacker cannot extract IAM credentials via unauthorized HTTP requests
  - AWS best practice for hardened instances

### 8. **Centralized Monitoring with CloudWatch**

**Decision**: Use CloudWatch for logs, metrics, and alarms

- **Rationale**:
  - Native AWS service; no separate monitoring infrastructure
  - Direct integration with SNS for alerting
  - CloudWatch Logs Insights for ad-hoc querying
- **Alternative Considered**: DataDog, New Relic (rejected due to added cost for small deployments)

### 9. **Subnet CIDR Calculation with Dynamic Sizing**

**Decision**: Use `cidrsubnet()` with configurable `subnet_newbits`

- **Rationale**:
  - Automatically sizes subnets based on VPC CIDR block (handles /16, /20, /24, etc.)
  - Prevents invalid subnet creation (e.g., /32 from /24 VPC)
  - Easily override per environment if needed
- **Example**: `/24` VPC with `newbits=4` → `/28` subnets (16 IPs each)

### 10. **Staging & Production Environment Separation**

**Decision**: Separate Terraform workspaces and EC2 instances per environment

- **Rationale**:
  - Isolates blast radius; production bugs don't affect staging
  - Different configurations (instance types, alarm thresholds)
  - Enables blue-green deployments and canary testing
- **Cost**: Doubled infrastructure cost, but acceptable for production safety

---

## Assumptions

### 1. **AWS Account Setup**

- Assumes you have an AWS account with appropriate IAM permissions
- User running Terraform has `AdministratorAccess` or equivalent (should be narrowed in production)
- AWS region is `eu-west-2` (London); adjust `terraform.tfvars` for other regions

### 2. **GitHub Repository Access**

- You have a public GitHub repository forked/cloned with Actions enabled
- Secrets are properly configured in the repository settings
- The `main` and `staging` branches are protected (recommended but not enforced)

### 3. **Application Requirements**

- MuchToDo API runs on port `8080` by default (configurable via `PORT` env var)
- Application reads environment variables (`.env` file or `export` statements)
- Docker image builds successfully from `app/MuchToDo/Dockerfile`
- Application handles graceful shutdown on `SIGTERM` signals

### 4. **Internet Connectivity**

- EC2 instances require outbound internet access to:
  - Pull Docker images from ECR
  - Download Go dependencies (if rebuilding)
  - Connect to MongoDB URI (if external)
  - Publish logs/metrics to CloudWatch
- NAT Gateway provides this; private subnets route outbound traffic through NAT

### 5. **AWS Service Availability**

- S3, EC2, ECR, VPC, IAM, CloudWatch, SNS, CloudTrail are available in your region
- No service quotas exceeded (e.g., VPC limit, NAT Gateway limit)
- Default VPC and security group restrictions are acceptable

### 6. **Database Configuration**

- MongoDB URI is externally managed (not provisioned in this infrastructure)
- Connection string is securely passed via `MONGO_URI` environment variable
- Assumes MongoDB is reachable from EC2 (via internet, private network, etc.)

### 7. **TLS/SSL Certificates**

- HTTP traffic on port 80 is routed directly to port 8080 (unencrypted)
- For production, assumes CloudFront/ALB with SSL termination will sit in front (outside scope of this assessment)
- Security Group allows HTTP/HTTPS; HTTPS ingress rule present for future load balancer integration

---

## Limitations & Improvements

### Current Limitations

#### 1. **Single EC2 Instance per Environment**

- **Limitation**: No redundancy; single instance failure = downtime
- **Impact**: ~15-30 min recovery time during outages
- **Improvement**: Deploy multi-instance setup with Application Load Balancer (ALB) and auto-scaling group
  ```hcl
  # Future: ALB with target group and ASG with desired_capacity = 2+
  # enables rolling updates without downtime
  ```

#### 2. **No Database Provisioning**

- **Limitation**: MongoDB must be managed externally; no automated backups
- **Impact**: Data loss risk if external database fails
- **Improvement**:
  - Option 1: Provision AWS DocumentDB (MongoDB-compatible) or use MongoDB Atlas
  - Option 2: Add backup automation via AWS Database Migration Service (DMS)

#### 3. **No Cache Layer**

- **Limitation**: Redis/ElastiCache not deployed; every request hits MongoDB
- **Impact**: Higher latency and database load at scale
- **Improvement**:
  - Deploy ElastiCache Redis cluster in private subnets
  - Update security group ingress to allow EC2 → Redis communication
  - Application already supports `ENABLE_CACHE` flag

#### 4. **Manual Environment Variable Management**

- **Limitation**: Secrets stored as base64-encoded strings in GitHub
- **Impact**: Risk of accidental secret leaks in repository history
- **Improvement**:
  - Use AWS Secrets Manager to centralize secret storage
  - Update IAM role to allow EC2 read access to Secrets Manager
  - Modify SSM deployment script to fetch secrets at runtime

#### 5. **No Log Retention Limits Enforcement**

- **Limitation**: CloudWatch log retention could grow indefinitely
- **Impact**: Storage cost surprises if not monitored
- **Improvement**:
  - Set explicit `retention_in_days` (currently 30 days, good for staging)
  - Archive old logs to S3 for long-term compliance storage

#### 6. **No Rate Limiting on Application Load**

- **Limitation**: Single EC2 instance can be overwhelmed by traffic spikes
- **Impact**: DoS vulnerability; service degradation under load
- **Improvement**:
  - Implement rate limiting in the application (middleware)
  - Add AWS WAF rules on CloudFront/ALB
  - Use CloudFront caching for static/cacheable responses

#### 7. **Alarm Notifications Only via Email/SNS**

- **Limitation**: SNS topic requires manual subscription management
- **Impact**: Alerts may be missed if email is not monitored
- **Improvement**:
  - Integrate with PagerDuty, Slack, or Opsgenie for incident management
  - Add SMS for critical production alarms

#### 8. **No Disaster Recovery Plan**

- **Limitation**: No cross-region backup or failover mechanism
- **Impact**: Regional AWS outage = total service downtime
- **Improvement**:
  - Implement cross-region replication for critical data
  - Deploy standby infrastructure in secondary region
  - Implement Route 53 failover routing policy

#### 9. **VPC Flow Logs Only for CloudWatch**

- **Limitation**: Limited query capabilities for large volumes of traffic data
- **Impact**: Difficult forensic analysis for security incidents
- **Improvement**:
  - Export VPC Flow Logs to S3 for long-term archival
  - Integrate with AWS Athena or Splunk for advanced analytics

#### 10. **No Infrastructure Testing**

- **Limitation**: Terraform configuration not validated against real AWS state
- **Impact**: Plan-time failures discovered only during apply
- **Improvement**:
  - Use Terraform testing tools (Terratest, Checkov)
  - Implement policy-as-code (OPA, Sentinel) for compliance checks

### Short-Term Improvements (1-3 months)

1. **Add Application Load Balancer (ALB)**
   - Enable zero-downtime deployments
   - Support HTTPS termination
   - Integrate CloudFront for DDoS protection

2. **Implement Secrets Manager Integration**
   - Replace GitHub secret encoding
   - Rotate credentials automatically
   - Centralize secret management

3. **Add Auto-Scaling Group**
   - Scale EC2 capacity based on CPU/network metrics
   - Support rolling updates
   - Improve availability to 99.9% SLA

4. **Implement Blue-Green Deployment**
   - Reduce deployment risk
   - Enable instant rollback
   - Support A/B testing

### Medium-Term Improvements (3-6 months)

1. **Migrate to ECS Fargate**
   - Serverless container orchestration
   - Automatic scaling
   - Reduced operational overhead

2. **Implement Service Mesh (Istio/Linkerd)**
   - Advanced traffic management
   - Mutual TLS between services
   - Observability (distributed tracing)

3. **Add API Gateway**
   - Rate limiting and throttling
   - Request/response transformation
   - OpenAPI/Swagger documentation

4. **Implement Database Replication**
   - Multi-availability zone MongoDB setup
   - Automated failover
   - Read replicas for scaling reads

### Long-Term Improvements (6+ months)

1. **Implement Kubernetes Cluster**
   - EKS for managed Kubernetes
   - Multi-region deployments
   - Advanced orchestration capabilities

2. **Implement CI/CD Enhancements**
   - Automated performance testing
   - Security scanning (SAST, DAST)
   - Compliance validation

3. **Build Observability Stack**
   - Prometheus + Grafana for metrics
   - ELK Stack or Splunk for logging
   - Jaeger for distributed tracing

---

## Repository Structure

```
damolak-devops-assesment/
├── .github/
│   └── workflows/
│       ├── app.yml                 # CI/CD pipeline for MuchToDo API
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
│   │   └── remote-state/           # S3 + DynamoDB backend
│   ├── environments/
│   │   ├── staging/
│   │   │   ├── main.tf             # Staging module instantiation
│   │   │   ├── variables.tf        # Staging variables
│   │   │   ├── outputs.tf          # Staging outputs
│   │   │   ├── terraform.tfvars    # Staging configuration
│   │   │   └── backend.tf          # S3 backend configuration
│   │   └── production/             # Production identical to staging
│   └── README.md                   # Infrastructure documentation
├── script/
│   ├── deploy-infra.sh                 # Helper script for infrastructure deployment
│   └── destroy-infra.sh                # Helper script for infrastructure teardown
└── README.md                        # This file
```

---

## Prerequisites

### Software Requirements

- **Terraform**: v1.0 or later

  ```bash
  terraform --version
  ```

- **AWS CLI**: v2.x

  ```bash
  aws --version
  ```

- **Git**: Latest version

  ```bash
  git --version
  ```

- **Docker** (for local testing):

  ```bash
  docker --version
  ```

- **Go** (for application development):
  ```bash
  go version
  ```

---

## GitHub Secrets Setup

Create the following secrets in your GitHub repository:

### AWS Credentials

```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION              # e.g., eu-west-2
```

### ECR Configuration

```
ECR_REPOSITORY_BACKEND  # Name of your ECR repository
```

### Instance IDs

```
STAGING_INSTANCE_ID     # From terraform output: module.instance.instance_id
PRODUCTION_INSTANCE_ID  # From terraform output: module.instance.instance_id
```

### Environment Files (Base64-encoded)

```bash
# Create your .env file for staging
cat > staging.env <<EOF
PORT=8080
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/db
DB_NAME=much_todo_db
JWT_SECRET_KEY=your-secret-key-here
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=true
REDIS_ADDR=redis.internal:6379
LOG_LEVEL=INFO
LOG_FORMAT=json
ALLOWED_ORIGINS=https://staging.yourapp.com,http://localhost:5173
COOKIE_DOMAINS=staging.yourapp.com
SECURE_COOKIE=true
EOF

# Encode to base64 and copy to GitHub
cat staging.env | base64 -w 0
```

Then create GitHub secrets:

- `STAGING_ENV_FILE`: Base64-encoded staging.env
- `PRODUCTION_ENV_FILE`: Base64-encoded production.env

---

## Troubleshooting

### Terraform Issues

#### Error: "Subnet CIDR Range Invalid"

```
Error: creating EC2 Subnet: operation error EC2: CreateSubnet, ...
api error InvalidSubnet.Range: The CIDR '10.8.1.0/32' is invalid.
```

**Solution**:

- Adjust `subnet_newbits` variable; default is 4 for /28 subnets
- For /24 VPC, newbits must be <= 8 (to avoid /32 subnets)
- Update tfvars: `subnet_newbits = 4`

#### Error: "Null value in list"

```
Error: on ../../modules/instance/main.tf line 60, in resource "aws_instance"
vpc_security_group_ids = [var.backend_sg_id]
```

**Solution**:

- Pass `backend_sg_id` from network module to instance module
- In `main.tf`: `backend_sg_id = module.network.backend_sg_id`

#### Error: "User is not authorized to perform: iam:\*"

```
Error: Error creating IAM role: AccessDenied: User: arn:aws:iam::...
```

**Solution**:

- Ensure AWS credentials are configured
- Check IAM permissions for the authenticated user
- Run: `aws iam get-user` to verify identity

### Deployment Issues

#### SSM Send-Command Fails

```
An error occurred (InvalidInstanceID.Malformed) when calling the SendCommand operation
```

**Solution**:

- Verify instance ID from Terraform outputs
- Ensure EC2 instance is in `running` state
- Check IAM role has `AmazonSSMManagedInstanceCore` policy
- Verify EC2 can reach Systems Manager (requires NAT or VPC endpoint)

#### Docker Pull Fails in SSM Command

```
Error response from daemon: errors: denied: requested access to resource is denied
```

**Solution**:

- Verify EC2 IAM role has `AmazonEC2ContainerRegistryReadOnly` policy
- Check ECR repository policy allows EC2 role
- Ensure image exists in ECR: `aws ecr describe-images --repository-name muchtodo-backend`

#### Container Exits Immediately

```
docker: Error response from daemon: OCI runtime error
```

**Solution**:

- Check logs: `docker logs muchtodo-api`
- Verify `.env` file is mounted correctly: `docker inspect muchtodo-api`
- Ensure application can parse environment variables

### Network Issues

#### EC2 Cannot Reach External Resources

**Solution**:

- Verify NAT Gateway is running: `aws ec2 describe-nat-gateways --filter "Name=state,Values=available"`
- Check private subnet route table points to NAT Gateway for `0.0.0.0/0`
- Verify security group allows egress (default is allow all)

#### VPC Flow Logs Not Appearing in CloudWatch

**Solution**:

- Check CloudWatch Logs group exists: `aws logs describe-log-groups`
- Verify IAM role for VPC Flow Logs has proper permissions
- Flow logs can take 5-10 minutes to appear; be patient

---

## Security Considerations

### 1. **Secrets Management**

- Never commit `.env` files or secrets to Git
- Use `git-secrets` pre-commit hook to prevent accidental commits
- Rotate secrets every 90 days

### 2. **IAM Least Privilege**

- Narrow IAM policies to specific resources
- Use role-based access control (RBAC) for humans
- Use temporary credentials (STS AssumeRole) for cross-account access

### 3. **Network Segmentation**

- EC2 in public subnet only if necessary
- Place databases in private subnets
- Use security groups as firewalls

### 4. **Encryption**

- Enable encryption in transit (TLS/HTTPS)
- Enable encryption at rest (EBS, RDS, S3)
- Use AWS KMS for key management

### 5. **Auditing & Logging**

- Enable CloudTrail for API logging
- Enable CloudWatch Logs for application logging
- Enable VPC Flow Logs for network logging
- Regularly review logs for suspicious activity

---
