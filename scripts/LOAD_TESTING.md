# Load Testing Guide

This guide shows you how to generate load on your demo application to test the Grafana dashboards.

## Quick Start

### Option 1: Quick Test (Recommended for First Try)

```bash
./scripts/quick-load-test.sh
```

Sends 100 requests over 10 seconds. Perfect for quickly seeing metrics in Grafana.

### Option 2: Interactive Load Test

```bash
./scripts/load-test.sh
```

Interactive menu with options:
- Light load (10 req/sec for 1 minute)
- Medium load (50 req/sec for 2 minutes)
- Heavy load (100 req/sec for 5 minutes)
- Spike test (burst traffic pattern)
- Custom test
- Error injection test

### Option 3: Advanced Load Testing

```bash
./scripts/advanced-load-test.sh
```

Uses professional load testing tools (requires installation):
- **Apache Bench (ab)**: Simple, built-in with httpd
- **wrk**: High-performance, recommended
- **hey**: Modern, easy to use

## Installation of Load Testing Tools

### macOS

```bash
# Apache Bench (comes with httpd)
brew install httpd

# wrk (recommended - fast and powerful)
brew install wrk

# hey (easy to use)
brew install hey
```

### Linux (Ubuntu/Debian)

```bash
# Apache Bench
sudo apt-get install apache2-utils

# wrk
sudo apt-get install wrk

# hey
wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
chmod +x hey_linux_amd64
sudo mv hey_linux_amd64 /usr/local/bin/hey
```

## Manual Testing Methods

### Method 1: Simple curl Loop

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Send 100 requests
for i in {1..100}; do
    curl -s -H "Host: demo.aks.internal" http://$INGRESS_IP/health > /dev/null
    echo "Request $i sent"
done
```

### Method 2: Parallel Requests with curl

```bash
# Send requests in parallel
for i in {1..50}; do
    curl -s -H "Host: demo.aks.internal" http://$INGRESS_IP/health > /dev/null &
done
wait
```

### Method 3: Using Apache Bench

```bash
# 1000 requests, 50 concurrent
ab -n 1000 -c 50 -H "Host: demo.aks.internal" http://$INGRESS_IP/health
```

### Method 4: Using wrk

```bash
# 30 seconds, 50 connections, 4 threads
wrk -t4 -c50 -d30s --latency -H "Host: demo.aks.internal" http://$INGRESS_IP/health
```

### Method 5: Using hey

```bash
# 1000 requests, 50 workers
hey -n 1000 -c 50 -H "Host: demo.aks.internal" http://$INGRESS_IP/health
```

## Testing Different Endpoints

```bash
INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Health endpoint
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/health

# Info endpoint
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/info

# Secret endpoint (tests Key Vault integration)
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/secret

# Root endpoint
curl -H "Host: demo.aks.internal" http://$INGRESS_IP/
```

## Load Test Scenarios

### Scenario 1: Baseline Test
**Goal**: Generate consistent traffic to populate dashboards

```bash
# Run for 2 minutes with steady load
./scripts/load-test.sh
# Choose option 2 (Medium load)
```

**What to observe in Grafana:**
- Ingress Metrics: Request rate stabilizes around 50 req/sec
- Application Health: CPU and memory increase slightly
- Cluster Health: Overall cluster metrics show increased activity

### Scenario 2: Spike Test
**Goal**: Test dashboard response to traffic spikes

```bash
./scripts/load-test.sh
# Choose option 4 (Spike test)
```

**What to observe:**
- Ingress Metrics: Sharp increase in request rate
- Response Latency: P95/P99 latency may increase during spike
- Application Health: CPU spikes visible in pod metrics

### Scenario 3: Error Generation
**Goal**: Test error rate monitoring

```bash
./scripts/load-test.sh
# Choose option 6 (Error injection)
```

**What to observe:**
- Ingress Metrics: 4xx error rate increases
- HTTP Status Codes: Mix of 2xx and 4xx responses
- Application Health: Error rate metrics update

### Scenario 4: Sustained Load
**Goal**: Monitor long-term behavior

```bash
# Heavy load for 5 minutes
./scripts/load-test.sh
# Choose option 3 (Heavy load)
```

**What to observe:**
- Cluster Health: Node CPU/memory trends over time
- Pod Restarts: Should remain at 0
- Resource Requests vs Limits: See how cluster capacity is used

## Grafana Dashboard Checklist

After running load tests, verify these metrics are visible:

### Cluster Health Overview Dashboard
- [ ] Node CPU utilization shows activity
- [ ] Node Memory utilization updates
- [ ] Pod Restarts table shows demo-app namespace
- [ ] CPU/Memory requests vs limits charts populate

### Ingress Metrics Dashboard
- [ ] Total Request Rate shows non-zero value
- [ ] Request Rate by Ingress shows sample-api
- [ ] Response Latency Percentiles display (P50, P95, P99)
- [ ] HTTP Status Codes show 2xx responses
- [ ] Top Services table shows demo-app entries

### Application Health Dashboard
- [ ] Application Status shows "Running" (green)
- [ ] Running Pods count is correct
- [ ] Request Volume by Pod distributes traffic
- [ ] CPU Usage by Pod shows activity
- [ ] Memory Usage by Pod displays values

## Troubleshooting

### No metrics showing in dashboards

1. **Check if Prometheus is scraping:**
   ```bash
   kubectl get pods -n kube-system | grep ama-metrics
   ```

2. **Verify data collection rule:**
   ```bash
   cd infra/terraform/envs/dev
   terraform output | grep monitor
   ```

3. **Check Grafana data source:**
   - Go to Grafana → Configuration → Data Sources
   - Verify Prometheus connection

### Load test fails with connection errors

1. **Verify ingress is working:**
   ```bash
   kubectl get ingress -n demo-app
   kubectl describe ingress sample-api -n demo-app
   ```

2. **Test direct connection:**
   ```bash
   INGRESS_IP=$(kubectl get ingress -n demo-app sample-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
   curl -v -H "Host: demo.aks.internal" http://$INGRESS_IP/health
   ```

3. **Check app pods:**
   ```bash
   kubectl get pods -n demo-app
   kubectl logs -n demo-app -l app=sample-api
   ```

### Metrics delay

Prometheus scrapes metrics every 30 seconds by default. Allow 1-2 minutes for metrics to appear in Grafana after generating load.

## Best Practices

1. **Start small**: Begin with quick-load-test.sh to verify everything works
2. **Check dashboards**: Open Grafana dashboards BEFORE running load tests
3. **Set time range**: In Grafana, set time range to "Last 5 minutes" with auto-refresh
4. **Run sustained tests**: For best dashboard visibility, run tests for at least 2-3 minutes
5. **Monitor resources**: Keep an eye on pod resource usage during heavy load tests

## Next Steps

After verifying dashboards with load testing:

1. **Create alerts**: Set up alert rules for high error rates or latency
2. **Baseline metrics**: Document normal operating ranges
3. **Auto-scaling**: Consider enabling HPA based on observed metrics
4. **Optimize**: Use insights to adjust resource requests/limits

## References

- [Apache Bench Documentation](https://httpd.apache.org/docs/2.4/programs/ab.html)
- [wrk Documentation](https://github.com/wg/wrk)
- [hey Documentation](https://github.com/rakyll/hey)
- [Grafana Dashboard Guide](../docs/dashboards.md)
