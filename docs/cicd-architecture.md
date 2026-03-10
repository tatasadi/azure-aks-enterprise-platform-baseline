# CI/CD Architecture

This document describes the continuous integration and deployment workflows for the AKS Enterprise Platform.

## Table of Contents

1. [Pipeline Overview](#pipeline-overview)
2. [Infrastructure Pipeline Flow](#infrastructure-pipeline-flow)
3. [Application Pipeline Flow](#application-pipeline-flow)
4. [Security and Approval Gates](#security-and-approval-gates)
5. [Deployment Strategies](#deployment-strategies)

---

## Pipeline Overview

The platform uses two distinct pipelines following the separation of concerns principle:

```mermaid
graph TB
    subgraph "Code Repository"
        A[infra/terraform/**]
        B[app/**]
    end

    subgraph "CI/CD Pipelines"
        C[Infrastructure Pipeline]
        D[Application Pipeline]
    end

    subgraph "Azure Resources"
        E[AKS Cluster]
        F[ACR + Monitoring]
        G[Key Vault]
    end

    A -->|triggers| C
    B -->|triggers| D
    C -->|provisions| E
    C -->|provisions| F
    C -->|provisions| G
    D -->|builds image| F
    D -->|deploys to| E
    D -->|uses secrets from| G
```

---

## Infrastructure Pipeline Flow

### High-Level Flow

```mermaid
flowchart TD
    A[Code Change in infra/**] --> B{Branch?}
    B -->|PR to main| C[Validate Stage]
    B -->|main branch| C

    C --> D[Terraform Init]
    D --> E[Format Check]
    E --> F[Terraform Validate]
    F --> G{Validation OK?}

    G -->|No| H[Pipeline Fails]
    G -->|Yes| I[Plan Stage]

    I --> J[Terraform Init]
    J --> K[Terraform Plan]
    K --> L[Publish Plan Artifact]
    L --> M{Branch = main?}

    M -->|No| N[Stop - Plan Only]
    M -->|Yes| O[Apply Stage]

    O --> P{Manual Approval}
    P -->|Rejected| Q[Pipeline Cancelled]
    P -->|Approved| R[Download Plan]
    R --> S[Terraform Init]
    S --> T[Terraform Apply]
    T --> U[Verify AKS Cluster]
    U --> V[Pipeline Success]
```

### Stage Details

#### 1. Validate Stage
**Purpose**: Ensure Terraform code quality before execution

**Steps**:
1. Install Terraform (version 1.5.7)
2. Initialize Terraform backend
3. Check code formatting (`terraform fmt -check -recursive`)
4. Validate configuration (`terraform validate`)

**Outputs**: None (validation only)

**Duration**: ~1-2 minutes

#### 2. Plan Stage
**Purpose**: Generate execution plan and review changes

**Steps**:
1. Install Terraform
2. Initialize backend (connects to Azure Storage)
3. Get current user's Entra ID object ID
4. Generate plan with variables
5. Save plan to file (`tfplan`)
6. Convert plan to readable text
7. Publish plan as artifact

**Artifacts**:
- `terraform-plan`: Binary plan file
- `plan-output`: Human-readable plan

**Duration**: ~2-3 minutes

#### 3. Apply Stage (Conditional)
**Purpose**: Execute Terraform changes in Azure

**Conditions**:
- Only runs on `main` branch
- Requires manual approval via Environment gate

**Steps**:
1. Checkout code
2. Install Terraform
3. Download plan artifact from previous stage
4. Initialize backend
5. Apply plan (`terraform apply -auto-approve tfplan`)
6. Display outputs (cluster name, Grafana URL, etc.)
7. Verify AKS cluster health (`kubectl get nodes`)

**Duration**: ~15-20 minutes (depends on changes)

---

## Application Pipeline Flow

### High-Level Flow

```mermaid
flowchart TD
    A[Code Change in app/**] --> B{Branch?}
    B -->|PR to main| C[Build Stage]
    B -->|main branch| C

    C --> D[Build Docker Image]
    D --> E[Push to ACR]
    E --> F[Security Scan with Trivy]
    F --> G[Publish K8s Manifests]
    G --> H[Validate Stage]

    H --> I[Download Manifests]
    I --> J[Install kubeval]
    J --> K[Validate All YAML Files]
    K --> L{Validation OK?}

    L -->|No| M[Pipeline Fails]
    L -->|Yes| N{Branch = main?}

    N -->|No| O[Stop - Build Only]
    N -->|Yes| P[Deploy Stage]

    P --> Q{Manual Approval}
    Q -->|Rejected| R[Pipeline Cancelled]
    Q -->|Approved| S[Get AKS Credentials]
    S --> T[Update Image Tag]
    T --> U[Apply Namespace]
    U --> V[Apply ServiceAccount]
    V --> W[Apply SecretProviderClass]
    W --> X[Apply Deployment]
    X --> Y[Apply Service]
    Y --> Z[Apply Ingress]
    Z --> AA[Apply PodMonitor]
    AA --> AB[Wait for Rollout]
    AB --> AC{Deployment Success?}

    AC -->|Yes| AD[Verify Deployment]
    AC -->|No| AE[Show Rollback Instructions]
    AD --> AF[Pipeline Success]
```

### Stage Details

#### 1. Build Stage
**Purpose**: Build and publish container image

**Steps**:
1. Build Docker image with multi-architecture support (`linux/amd64`)
2. Tag image with:
   - Build ID (e.g., `12345`)
   - `latest` tag
3. Push both tags to Azure Container Registry
4. Run Trivy security scan (HIGH/CRITICAL vulnerabilities)
5. Publish Kubernetes manifests as artifact

**Artifacts**:
- Container images in ACR
- `k8s-manifests`: Deployment files

**Duration**: ~3-5 minutes

#### 2. ValidateManifests Stage
**Purpose**: Validate Kubernetes manifest syntax

**Steps**:
1. Download manifests artifact
2. Install kubeval tool
3. Validate each YAML file against Kubernetes schemas
4. Check for deprecated API versions

**Duration**: ~1 minute

#### 3. DeployDev Stage (Conditional)
**Purpose**: Deploy application to AKS cluster

**Conditions**:
- Only runs on `main` branch
- Requires manual approval via Environment gate

**Steps**:
1. Download manifests artifact
2. Get AKS credentials via Azure CLI
3. Update deployment.yaml with new image tag
4. Apply manifests in order:
   - Namespace
   - ServiceAccount
   - SecretProviderClass
   - Deployment
   - Service
   - Ingress
   - PodMonitor
5. Wait for deployment rollout (5 minute timeout)
6. Verify deployment health
7. Display ingress IP and test commands

**Duration**: ~3-5 minutes

#### 4. RollbackOnFailure Stage (Conditional)
**Purpose**: Provide rollback guidance on deployment failure

**Conditions**:
- Only runs if DeployDev fails

**Steps**:
1. Display manual rollback instructions
2. Show kubectl commands for checking deployment status
3. Provide rollback commands

---

## Security and Approval Gates

### Infrastructure Pipeline Security

```mermaid
graph TD
    A[Service Principal] -->|Contributor| B[Azure Subscription]
    B --> C[Terraform State Storage]
    B --> D[AKS Resource Group]

    E[Environment: aks-platform-dev] -->|Manual Approval| F[Apply Stage]
    G[Approver: Platform Team] --> E

    H[Terraform Backend] -->|State Locking| C
    H -->|Prevents| I[Concurrent Modifications]
```

**Security Controls**:
- **Service Principal**: Least privilege (Contributor, not Owner)
- **State Locking**: Prevents concurrent Terraform applies
- **Approval Gate**: Manual approval required for Apply stage
- **Plan Review**: Plan artifact published for review before apply
- **Format Check**: Ensures code consistency
- **Validation**: Catches syntax errors before execution

### Application Pipeline Security

```mermaid
graph TD
    A[ACR Service Connection] -->|Push Images| B[Azure Container Registry]
    C[AKS Service Connection] -->|Deploy Apps| D[AKS Cluster]

    E[Trivy Scanner] -->|Scans| F[Container Image]
    F -->|No Critical Vulns| G[Push to ACR]

    H[Environment: aks-demo-app-dev] -->|Manual Approval| I[Deploy Stage]
    J[Approver: App Team] --> H

    K[kubeval] -->|Validates| L[K8s Manifests]
    L -->|Valid| M[Deployment]
```

**Security Controls**:
- **Image Scanning**: Trivy scans for vulnerabilities (currently warning-only)
- **Manifest Validation**: kubeval prevents invalid Kubernetes resources
- **Approval Gate**: Manual approval required for deployment
- **Least Privilege**: AKS identity has minimal required permissions
- **Secrets Management**: Uses Azure Key Vault via Workload Identity
- **No Hardcoded Secrets**: All credentials via service connections

### Approval Gates Configuration

**Infrastructure Pipeline**:
- **Environment**: `aks-platform-dev`
- **Approvers**: Platform Team Lead, DevOps Lead
- **Timeout**: 7 days (auto-reject after)
- **Required Approvals**: 1

**Application Pipeline**:
- **Environment**: `aks-demo-app-dev`
- **Approvers**: Application Team Lead, On-Call Engineer
- **Timeout**: 2 days
- **Required Approvals**: 1

---

## Deployment Strategies

### Current Strategy: Rolling Update

The platform currently uses Kubernetes Rolling Updates for zero-downtime deployments.

```mermaid
sequenceDiagram
    participant P as Pipeline
    participant K as Kubernetes
    participant O as Old Pods (v1)
    participant N as New Pods (v2)

    P->>K: Apply deployment with new image
    K->>N: Create new pod (v2)
    N->>N: Wait for readiness probe
    N-->>K: Pod ready
    K->>O: Terminate one old pod (v1)
    K->>N: Create another new pod (v2)
    N->>N: Wait for readiness probe
    N-->>K: Pod ready
    K->>O: Terminate another old pod (v1)
    Note over K: Repeat until all pods updated
    K-->>P: Rollout complete
```

**Configuration**:
```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0       # Keep all pods available during update
      maxSurge: 1             # Allow 1 extra pod during update
```

**Characteristics**:
- ✅ Zero downtime
- ✅ Gradual rollout
- ✅ Easy rollback
- ⚠️ Both versions run simultaneously during update

### Future Strategies (Not Implemented)

#### Canary Deployment
```mermaid
graph LR
    A[Ingress] --> B{Traffic Split}
    B -->|90%| C[Stable v1]
    B -->|10%| D[Canary v2]
    D -->|Monitor metrics| E{Healthy?}
    E -->|Yes| F[Gradually increase to 100%]
    E -->|No| G[Rollback to v1]
```

**Use Case**: High-risk deployments where gradual traffic shift is needed

**Requirements**: Service mesh (Istio, Linkerd) or NGINX Ingress with traffic splitting

#### Blue-Green Deployment
```mermaid
graph TD
    A[Pipeline Deploys Green]
    A --> B[Blue Active, Green Idle]
    B --> C[Run Tests on Green]
    C --> D{Tests Pass?}
    D -->|Yes| E[Switch Traffic to Green]
    D -->|No| F[Keep Blue Active]
    E --> G[Green Active, Blue Idle]
    G --> H[Optional: Delete Blue]
```

**Use Case**: Instant rollback requirement, database migration testing

**Requirements**: Dual environment slots, load balancer reconfiguration

---

## Pipeline Metrics and Monitoring

### Key Metrics to Track

| Metric | Target | Importance |
|--------|--------|------------|
| Infrastructure pipeline duration | < 25 min | Developer productivity |
| Application pipeline duration | < 10 min | Deployment frequency |
| Deployment success rate | > 95% | Reliability |
| Time to rollback | < 5 min | Incident recovery |
| Failed deployments per week | < 2 | Quality |
| Terraform plan changes | Review all | Change awareness |

### Pipeline Dashboards

Monitor pipeline health in Azure DevOps:
- **Analytics → Pipeline Analytics**: Success rate, duration trends
- **Pipeline → Runs**: Recent execution history
- **Environments → Deployments**: Deployment history per environment

### Alerts to Configure

1. **Pipeline Failure**:
   - Trigger: Any pipeline run fails
   - Action: Notify team channel

2. **Long-Running Pipeline**:
   - Trigger: Infrastructure pipeline > 30 min
   - Action: Investigate performance

3. **Pending Approval**:
   - Trigger: Approval waiting > 4 hours
   - Action: Notify approvers

4. **Deployment Rollback**:
   - Trigger: `kubectl rollout undo` executed
   - Action: Create incident ticket

---

## Integration with GitOps (Future Enhancement)

### Current State: Push-Based Deployment
Pipelines directly apply changes to cluster using `kubectl`.

### Future State: Pull-Based GitOps

```mermaid
graph TD
    A[Code Change] --> B[Pipeline Builds Image]
    B --> C[Pipeline Updates Manifest Repo]
    C --> D[GitOps Operator Detects Change]
    D --> E[Operator Pulls Changes]
    E --> F[Operator Applies to Cluster]
    F --> G[Continuous Reconciliation]
```

**Benefits**:
- Cluster state declarative in Git
- Automatic drift correction
- Better audit trail
- Multi-cluster support

**Tools to Consider**:
- **Flux CD**: Lightweight, native Kubernetes
- **Argo CD**: Full-featured UI, ApplicationSets
- **Azure Arc GitOps**: Azure-native, multi-cluster

---

## Troubleshooting Common Pipeline Issues

### Infrastructure Pipeline

| Issue | Cause | Solution |
|-------|-------|----------|
| State lock timeout | Concurrent apply running | Break lock after confirming no active applies |
| Plan shows unexpected changes | Manual changes in Azure | Import resources or revert manual changes |
| Format check fails | Unformatted code | Run `terraform fmt -recursive` locally |
| Validate fails | Syntax error | Fix error shown in output |
| Apply timeout | Large infrastructure change | Increase timeout or split changes |

### Application Pipeline

| Issue | Cause | Solution |
|-------|-------|----------|
| Image build fails | Dockerfile error | Test build locally with Docker |
| Trivy scan fails | Critical vulnerabilities | Update base image or dependencies |
| kubeval fails | Invalid manifest | Fix manifest syntax errors |
| Deployment timeout | Pod not starting | Check pod logs and events |
| Rollout stuck | Readiness probe failing | Review probe configuration |
| Image pull error | ACR authentication | Verify AcrPull role assignment |

---

## References

- [Azure DevOps Pipelines](https://learn.microsoft.com/azure/devops/pipelines/)
- [Terraform in CI/CD](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [GitOps Principles](https://opengitops.dev/)

---

**Last Updated**: 2026-03-10
