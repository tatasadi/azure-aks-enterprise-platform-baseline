# Sample API

A demonstration Python Flask REST API showcasing Azure AKS Enterprise Platform features including Workload Identity, Key Vault integration, and Prometheus metrics instrumentation.

## Features

- **Azure Workload Identity Integration** - Secretless authentication using OIDC federation
- **Azure Key Vault CSI Driver** - Secure secrets retrieval mounted as files
- **Prometheus Metrics** - Full HTTP request instrumentation for observability
- **Health Endpoints** - Liveness and readiness probes
- **Container Security** - Non-root user, minimal image, security contexts

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | API information and available endpoints |
| `/health` | GET | Health check for liveness/readiness probes |
| `/info` | GET | Pod metadata and environment information |
| `/secret` | GET | Demonstrates secret retrieval from Key Vault via CSI driver |
| `/metrics` | GET | Prometheus metrics endpoint |

## Prometheus Metrics

### http_requests_total
- **Type:** Counter
- **Labels:** method, endpoint, status
- **Description:** Total HTTP requests

### http_request_duration_seconds
- **Type:** Histogram
- **Labels:** method, endpoint
- **Description:** Request duration for latency percentiles

### http_requests_in_progress
- **Type:** Gauge
- **Labels:** method, endpoint
- **Description:** Currently in-flight requests

## Building & Deployment

```bash
# Build for AMD64 (important for M1/M2 Macs)
docker build --platform linux/amd64 -t aksplatformdevacr.azurecr.io/sample-api:v1.1.0-amd64 .

# Push to ACR
az acr login --name aksplatformdevacr
docker push aksplatformdevacr.azurecr.io/sample-api:v1.1.0-amd64

# Deploy to AKS
kubectl apply -f ../k8s/
```

## Testing

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test endpoints
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/metrics

# Generate traffic for dashboard testing
../../scripts/load-test/quick-load-test.sh
```

See [../../docs/dashboards.md](../../docs/dashboards.md) for Grafana dashboard usage.
