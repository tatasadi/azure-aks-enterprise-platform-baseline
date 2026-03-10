# Grafana Dashboards

This document describes the custom Grafana dashboards created for monitoring the AKS Enterprise Platform.

## Table of Contents

1. [Dashboard Overview](#dashboard-overview)
2. [Accessing Grafana](#accessing-grafana)
3. [Importing Dashboards](#importing-dashboards)
4. [Dashboard Catalog](#dashboard-catalog)
5. [Metrics Reference](#metrics-reference)
6. [Troubleshooting](#troubleshooting)

---

## Dashboard Overview

The AKS Enterprise Platform includes three custom Grafana dashboards designed to provide comprehensive observability:

| Dashboard | Purpose | Key Metrics | Audience |
|-----------|---------|-------------|----------|
| **Cluster Health Overview** | Monitor overall cluster health and resource utilization | CPU, memory, pod restarts, resource requests/limits | Platform Team |
| **Ingress Metrics** | Track ingress traffic patterns and performance | Request rates, latency, error rates, HTTP status codes | Platform + App Teams |
| **Application Health** | Monitor application-specific performance and errors | Pod status, request volume, errors, resource usage | Application Teams |

---

## Accessing Grafana

### Get Grafana URL

```bash
cd infra/terraform/envs/dev
terraform output grafana_endpoint
```

Example output:
```
https://aksplatform-dev-grafana-xxxxx.weu.grafana.azure.com
```

### Authentication

Azure Managed Grafana uses Entra ID authentication:

1. Navigate to the Grafana URL in your browser
2. Sign in with your Entra ID credentials
3. Ensure you have been assigned the **Grafana Admin** role (configured via Terraform)

### Verifying Access

1. Log into Grafana
2. Navigate to **Configuration** -> **Data Sources**
3. Verify that **Azure Monitor managed service for Prometheus** is connected
4. Test the connection

---

## Importing Dashboards

### Method 1: Import via Grafana UI

1. Log into Grafana
2. Click **Dashboards** -> **Import** (+ icon in sidebar)
3. Click **Upload JSON file**
4. Select one of the dashboard files from [`platform/manifests/grafana-dashboards/`](../platform/manifests/grafana-dashboards/)
5. Select the Prometheus data source
6. Click **Import**

### Method 2: Import via API (Optional)

```bash
# Set variables
GRAFANA_URL="https://aksplatform-dev-grafana-xxxxx.weu.grafana.azure.com"
DASHBOARD_FILE="platform/manifests/grafana-dashboards/cluster-health-overview.json"

# Get Entra ID token
TOKEN=$(az account get-access-token --resource https://grafana.azure.com --query accessToken -o tsv)

# Import dashboard
curl -X POST "$GRAFANA_URL/api/dashboards/db" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @"$DASHBOARD_FILE"
```

### Dashboard Files

All dashboard JSON files are located in:
```
platform/manifests/grafana-dashboards/
├── cluster-health-overview.json
├── ingress-metrics.json
└── application-health.json
```

---

## Dashboard Catalog

### 1. AKS Cluster Health Overview

**File**: [cluster-health-overview.json](../platform/manifests/grafana-dashboards/cluster-health-overview.json)
**UID**: `aks-cluster-health`
**Refresh**: 30 seconds

#### Panels

| Panel | Description | Query | Thresholds |
|-------|-------------|-------|------------|
| **Cluster CPU Usage** | Average CPU utilization across all nodes | `avg(rate(node_cpu_seconds_total{mode!="idle"}[5m])) * 100` | Green: <80%, Red: >=80% |
| **Cluster Memory Usage** | Average memory utilization across all nodes | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | Green: <70%, Yellow: 70-85%, Red: >=85% |
| **Node CPU Utilization** | CPU usage per node (time series) | `avg by (node) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))` | - |
| **Node Memory Utilization** | Memory usage per node (time series) | `node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes` | - |
| **Pod Restarts by Namespace** | Pods with restarts in last 15 minutes | `sum(rate(kube_pod_container_status_restarts_total[15m])) by (namespace, pod)` | Green: < 3, Red: >=3 |
| **Cluster CPU Requests vs Limits** | Resource allocation trends | `sum(kube_pod_container_resource_requests{resource="cpu"}) / sum(kube_node_status_allocatable{resource="cpu"})` | - |
| **Cluster Memory Requests vs Limits** | Memory allocation trends | `sum(kube_pod_container_resource_requests{resource="memory"}) / sum(kube_node_status_allocatable{resource="memory"})` | - |
| **Persistent Volume Usage** | PV utilization by claim | `sum by (persistentvolumeclaim, namespace) (kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes)` | - |

#### Use Cases

- Monitor cluster capacity and identify resource constraints
- Detect abnormal pod restart patterns
- Track resource allocation efficiency
- Plan capacity upgrades

---

### 2. AKS Ingress Metrics

**File**: [ingress-metrics.json](../platform/manifests/grafana-dashboards/ingress-metrics.json)
**UID**: `aks-ingress-metrics`
**Refresh**: 30 seconds

#### Panels

| Panel | Description | Query | Thresholds |
|-------|-------------|-------|------------|
| **Total Request Rate** | Aggregate requests/second across all ingresses | `sum(rate(nginx_ingress_controller_requests[5m]))` | - |
| **5xx Error Rate** | Percentage of 5xx errors | `sum(rate(nginx_ingress_controller_requests{status=~"5.."}[5m])) / sum(rate(nginx_ingress_controller_requests[5m]))` | Green: <1%, Yellow: 1-5%, Red: >=5% |
| **4xx Error Rate** | Percentage of 4xx errors | `sum(rate(nginx_ingress_controller_requests{status=~"4.."}[5m])) / sum(rate(nginx_ingress_controller_requests[5m]))` | Green: <5%, Yellow: 5-10%, Red: >=10% |
| **P95 Latency** | 95th percentile response time | `histogram_quantile(0.95, sum(rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) by (le)) * 1000` | Green: <500ms, Yellow: 500-1000ms, Red: >=1000ms |
| **Request Rate by Ingress** | Traffic breakdown by ingress resource | `sum by (ingress) (rate(nginx_ingress_controller_requests[5m]))` | - |
| **Request Rate by Path** | Traffic breakdown by URL path | `sum by (path) (rate(nginx_ingress_controller_requests[5m]))` | - |
| **Response Latency Percentiles** | P50, P95, P99 response times | `histogram_quantile(0.95, sum(rate(nginx_ingress_controller_request_duration_seconds_bucket[5m])) by (le, ingress))` | - |
| **HTTP Status Codes** | Stacked time series by status code family | `sum by (status) (rate(nginx_ingress_controller_requests[5m]))` | - |
| **Top Services by Request Count** | Table of most active services | `topk(10, sum by (ingress, service) (rate(nginx_ingress_controller_requests[5m])))` | - |

#### Use Cases

- Identify traffic patterns and peak loads
- Detect performance degradation (latency spikes)
- Monitor error rates and troubleshoot failing endpoints
- Analyze which services receive the most traffic

---

### 3. AKS Application Health

**File**: [application-health.json](../platform/manifests/grafana-dashboards/application-health.json)
**UID**: `aks-application-health`
**Refresh**: 30 seconds

#### Template Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `$namespace` | Kubernetes namespace | `demo-app` |
| `$app` | Application name prefix | `sample-api` |

#### Panels

| Panel | Description | Query | Thresholds |
|-------|-------------|-------|------------|
| **Application Status** | Overall application health indicator | `min(kube_pod_status_phase{namespace="$namespace", pod=~"$app.*", phase="Running"})` | Red: Down, Green: Running |
| **Running Pods** | Number of pods in Running state | `count(kube_pod_status_phase{namespace="$namespace", pod=~"$app.*", phase="Running"})` | Red: 0, Yellow: 1, Green: >=2 |
| **Pod Restarts (15m)** | Recent restart count | `sum(rate(kube_pod_container_status_restarts_total{namespace="$namespace", pod=~"$app.*"}[15m]))` | Green: < 3, Yellow: 3-10, Red: >=10 |
| **P95 Response Time** | Application latency | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="$namespace", pod=~"$app.*"}[5m])) by (le)) * 1000` | Green: <500ms, Yellow: 500-1000ms, Red: >=1000ms |
| **Error Rate** | Percentage of 5xx errors | `sum(rate(http_requests_total{namespace="$namespace", pod=~"$app.*", status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="$namespace", pod=~"$app.*"}[5m]))` | Green: <1%, Yellow: 1-5%, Red: >=5% |
| **Request Rate** | Total requests/second | `sum(rate(http_requests_total{namespace="$namespace", pod=~"$app.*"}[5m]))` | - |
| **Request Volume by Pod** | Traffic distribution across replicas | `sum by (pod) (rate(http_requests_total{namespace="$namespace", pod=~"$app.*"}[5m]))` | - |
| **CPU Usage by Pod** | CPU consumption per pod | `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="$namespace", pod=~"$app.*", container!=""}[5m])) * 100` | - |
| **Memory Usage by Pod** | Memory consumption per pod | `sum by (pod) (container_memory_working_set_bytes{namespace="$namespace", pod=~"$app.*", container!=""})` | - |
| **HTTP Status Codes** | Response codes over time | `sum by (status) (rate(http_requests_total{namespace="$namespace", pod=~"$app.*"}[5m]))` | - |

#### Use Cases

- Monitor application-specific health and availability
- Detect performance issues at the application level
- Track resource consumption for capacity planning
- Correlate application errors with infrastructure issues

---

## Metrics Reference

### Prometheus Metrics Used

#### Node Metrics (node-exporter)

- `node_cpu_seconds_total` - CPU time spent in each mode
- `node_memory_MemTotal_bytes` - Total memory on the node
- `node_memory_MemAvailable_bytes` - Available memory on the node

#### Kubernetes State Metrics (kube-state-metrics)

- `kube_pod_status_phase` - Current phase of pods (Running, Pending, etc.)
- `kube_pod_container_status_restarts_total` - Total container restarts
- `kube_pod_container_resource_requests` - Resource requests (CPU, memory)
- `kube_pod_container_resource_limits` - Resource limits (CPU, memory)
- `kube_node_status_allocatable` - Allocatable resources per node

#### NGINX Ingress Controller Metrics

- `nginx_ingress_controller_requests` - Total HTTP requests
- `nginx_ingress_controller_request_duration_seconds_bucket` - Request duration histogram

#### Application Metrics (Custom - if instrumented)

- `http_requests_total` - Total HTTP requests (requires app instrumentation)
- `http_request_duration_seconds_bucket` - Request duration histogram (requires app instrumentation)

### Metric Labels

Common labels used in queries:

- `namespace` - Kubernetes namespace
- `pod` - Pod name
- `node` - Node name
- `container` - Container name
- `ingress` - Ingress resource name
- `service` - Service name
- `status` - HTTP status code
- `path` - HTTP request path

---

## Troubleshooting

### Dashboard Shows "No Data"

**Possible Causes**:

1. **Prometheus not scraping metrics**
   ```bash
   # Verify ama-metrics pods are running
   kubectl get pods -n kube-system | grep ama-metrics

   # Check ama-metrics logs
   kubectl logs -n kube-system -l rsName=ama-metrics
   ```

2. **Data collection rule not configured**
   ```bash
   # Verify Azure Monitor workspace integration
   az aks show -g aksplatform-dev-rg -n aksplatform-dev-aks \
     --query azureMonitorProfile
   ```

3. **Wrong data source selected**
   - Ensure dashboard is using the correct Prometheus data source
   - Go to **Dashboard Settings** -> **Variables** -> Check `$datasource`

### High Error Rates in Ingress Dashboard

**Troubleshooting Steps**:

1. Check ingress controller logs:
   ```bash
   kubectl logs -n app-routing-system -l app=nginx
   ```

2. Verify backend service health:
   ```bash
   kubectl get endpoints -A
   ```

3. Check for policy violations blocking requests:
   ```bash
   kubectl get events --all-namespaces --field-selector type=Warning
   ```

### Application Metrics Missing

**Note**: Application-specific metrics (like `http_requests_total`) require the application to be instrumented with Prometheus client libraries.

**Steps to Add Instrumentation**:

1. Add Prometheus client library to your application
2. Expose `/metrics` endpoint
3. Add Prometheus scrape annotations to pod:
   ```yaml
   metadata:
     annotations:
       prometheus.io/scrape: "true"
       prometheus.io/port: "8080"
       prometheus.io/path: "/metrics"
   ```

### Panels Show "Error" or "Bad Gateway"

1. Verify Grafana has Monitoring Reader role on Azure Monitor workspace:
   ```bash
   cd infra/terraform/envs/dev
   terraform plan  # Check role assignments
   ```

2. Test PromQL query directly:
   - Open **Explore** view in Grafana
   - Run a simple query: `up`
   - If this fails, check data source configuration

---

## Best Practices

### Dashboard Usage

1. **Start with Cluster Health** - Get overall cluster status before drilling down
2. **Use Time Range Selector** - Adjust time window to identify patterns
3. **Leverage Template Variables** - Use dropdowns to filter by namespace, app, etc.
4. **Set Up Alerts** - Configure alert rules for critical thresholds
5. **Export Dashboards Regularly** - Keep JSON files in version control

### Performance Considerations

1. Avoid queries with high cardinality (too many unique label combinations)
2. Use appropriate time ranges for rate calculations (e.g., `[5m]`)
3. Limit the number of panels on a single dashboard (max 15-20)
4. Use dashboard folders to organize by team or environment

### Customization

To modify dashboards:

1. Make changes in Grafana UI
2. Export updated JSON via **Dashboard Settings** -> **JSON Model**
3. Save to [`platform/manifests/grafana-dashboards/`](../platform/manifests/grafana-dashboards/)
4. Commit to Git for version control

---

## Additional Resources

- [Azure Managed Grafana Documentation](https://learn.microsoft.com/azure/managed-grafana/)
- [Prometheus Query Language (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- [NGINX Ingress Controller Metrics](https://kubernetes.github.io/ingress-nginx/user-guide/monitoring/)
- [kube-state-metrics Documentation](https://github.com/kubernetes/kube-state-metrics/tree/main/docs)

---

**Last Updated**: 2026-03-09
