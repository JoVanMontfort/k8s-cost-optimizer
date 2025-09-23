#!/bin/bash
# Usage: ./check-metrics.sh <API_KEY> <PROJECT_ID> <CLUSTER_NAME>

API_KEY="$1"
PROJECT_ID="$2"
CLUSTER_NAME="$3"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Cluster-wide CPU usage
CPU=$(curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
  -H "X-Auth-Token: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Project: $PROJECT_ID" \
  -d "{\"type\":\"metrics\",\"query\":\"avg(node_cpu_usage_percentage{cluster_name=~\\\"$CLUSTER_NAME\\\"})\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}" \
  | jq '.data.result[0].values[-1][1] | tonumber')
if (( $(echo "$CPU < 20" | bc -l) )); then
  echo "ALERT: Cluster CPU usage too low ($CPU%) - consider downsizing nodes!"
else
  echo "Cluster CPU usage: $CPU% (healthy)"
fi

# triggeriq pod CPU (namespace-specific)
TRIGGERIQ_CPU=$(curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
  -H "X-Auth-Token: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Project: $PROJECT_ID" \
  -d "{\"type\":\"metrics\",\"query\":\"sum(rate(container_cpu_usage_seconds_total{namespace=\\\"ingress-nginx\\\",pod=~\\\"triggeriq-.*\\\"}[5m])) * 1000\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}" \
  | jq '.data.result[0].values[-1][1] | tonumber')
if (( $(echo "$TRIGGERIQ_CPU < 50" | bc -l) )); then
  echo "ALERT: triggeriq CPU low ($TRIGGERIQ_CPU mCPU) - HPA may scale down."
else
  echo "triggeriq CPU: $TRIGGERIQ_CPU mCPU"
fi

# Etcd watchers for ingress-nginx
WATCHERS=$(curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
  -H "X-Auth-Token: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Project: $PROJECT_ID" \
  -d "{\"type\":\"metrics\",\"query\":\"sum(kubernetes_cluster_etcdwatcher_namespace_usage{cluster_name=~\\\"$CLUSTER_NAME\\\",namespace=\\\"ingress-nginx\\\"})\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}" \
  | jq '.data.result[0].values[-1][1] | tonumber')
if [ "$WATCHERS" -gt 50 ]; then
  echo "ALERT: High etcd watchers in ingress-nginx ($WATCHERS) - check polling!"
else
  echo "ingress-nginx etcd watchers: $WATCHERS"
fi

# HTTP requests (since Prometheus is enabled)
HTTP_RATE=$(curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
  -H "X-Auth-Token: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Project: $PROJECT_ID" \
  -d "{\"type\":\"metrics\",\"query\":\"sum(rate(http_requests_total{namespace=\\\"ingress-nginx\\\",job=~\\\"triggeriq.*\\\"}[5m]))\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}" \
  | jq '.data.result[0].values[-1][1] | tonumber')
if (( $(echo "$HTTP_RATE > 100" | bc -l) )); then
  echo "ALERT: High HTTP request rate ($HTTP_RATE req/s) - review scaling!"
else
  echo "triggeriq HTTP rate: $HTTP_RATE req/s"
fi