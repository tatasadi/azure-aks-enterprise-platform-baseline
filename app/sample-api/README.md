# Sample API Application

A lightweight Python Flask REST API demonstrating Azure AKS Enterprise Platform capabilities.

## Features

- **Health Checks**: `/health` endpoint for Kubernetes liveness/readiness probes
- **Pod Information**: `/info` endpoint exposing Kubernetes metadata
- **Secret Integration**: `/secret` endpoint reading from Azure Key Vault via CSI driver
- **Azure Workload Identity**: Secretless authentication to Azure services
- **Security Best Practices**: Runs as non-root user, minimal base image

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API information and available endpoints |
| `/health` | GET | Health check (returns 200 OK) |
| `/info` | GET | Pod metadata (hostname, namespace, version) |
| `/secret` | GET | Read secrets from Key Vault mounted volume |

## Local Development

### Prerequisites
- Python 3.11+
- Docker (for containerization)

### Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run the application
python app.py

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/info
```

### Build Docker Image

```bash
# Build the image
docker build -t sample-api:latest .

# Run the container
docker run -p 8080:8080 sample-api:latest

# Test
curl http://localhost:8080/health
```

## Deployment to AKS

### Build and Push to ACR

```bash
# Log in to Azure Container Registry
az acr login --name aksplatformdevacr

# Build and tag the image
docker build -t aksplatformdevacr.azurecr.io/sample-api:v1.0.0 .

# Push to ACR
docker push aksplatformdevacr.azurecr.io/sample-api:v1.0.0
```

### Deploy to Kubernetes

See [../k8s/README.md](../k8s/README.md) for Kubernetes manifest deployment instructions.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_VERSION` | `v1.0.0` | Application version |
| `PORT` | `8080` | HTTP server port |
| `SECRET_PATH` | `/mnt/secrets` | Path where Key Vault secrets are mounted |
| `POD_NAME` | - | Injected by Kubernetes (via downward API) |
| `POD_NAMESPACE` | - | Injected by Kubernetes (via downward API) |
| `NODE_NAME` | - | Injected by Kubernetes (via downward API) |

## Security

- Runs as non-root user (UID 1000)
- Minimal Python slim base image
- No secrets in environment variables
- Secrets read from mounted volumes (Key Vault CSI)
- Health checks enabled

## Architecture

This application demonstrates:
1. **Azure Workload Identity**: Pod authenticates to Entra ID using OIDC
2. **CSI Driver Integration**: Secrets mounted from Key Vault as files
3. **Kubernetes Best Practices**: Health probes, resource limits, labels
4. **12-Factor App Principles**: Configuration via environment, stateless design
