#!/bin/bash
# Usage: ./check-metrics.sh <API_KEY> <PROJECT_ID> <CLUSTER_NAME>

API_KEY="$1"
PROJECT_ID="$2"
CLUSTER_NAME="$3"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Function to query API and handle errors
query_api() {
  local query="$1"
  local result=$(curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
    -H "X-Auth-Token: $API_KEY" \
    -H "Content-Type: application/json" \
    -H "Project: $PROJECT_ID" \
    -d "{\"type\":\"metrics\",\"query\":\"$query\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}")
  echo "$result" | jq '.data.result[0].values[-1][1] // "null"' | tr -d '"'
}

# Cluster-wide CPU usage
CPU=$(query_api "avg(node_cpu_usage_percentage{cluster_name=~\\\"$CLUSTER_NAME\\\"})")
if [ "$CPU" = "null" ]; then
  echo "ERROR: Failed to fetch cluster CPU usage - check API_KEY, PROJECT_ID, or cluster name"
else
  if (( $(echo "$CPU < 20" | bc -l) )); then
    echo "ALERT: Cluster CPU usage too low ($CPU%) - consider downsizing nodes!"
  else
    echo "Cluster CPU usage: $CPU% (healthy)"
  fi
fi

# triggeriq pod CPU
TRIGGERIQ_CPU=$(query_api "sum(rate(container_cpu_usage_seconds_total{namespace=\\\"ingress-nginx\\\",pod=~\\\"triggeriq-.*\\\"}[5m])) * 1000")
if [ "$TRIGGERIQ_CPU" = "null" ]; then
  echo "ERROR: Failed to fetch triggeriq CPU - check Metrics Server or pod namespace"
else
  if (( $(echo "$TRIGGERIQ_CPU < 50" | bc -l) )); then
    echo "ALERT: triggeriq CPU low ($TRIGGERIQ_CPU mCPU) - HPA may scale down."
  else
    echo "triggeriq CPU: $TRIGGERIQ_CPU mCPU"
  fi
fi

# Etcd watchers for ingress-nginx
WATCHERS=$(query_api "sum(kubernetes_cluster_etcdwatcher_namespace_usage{cluster_name=~\\\"$CLUSTER_NAME\\\",namespace=\\\"ingress-nginx\\\"})")
if [ "$WATCHERS" = "null" ]; then
  echo "ERROR: Failed to fetch etcd watchers - check namespace or cluster metrics"
else
  if [ "$WATCHERS" -gt 50 ] 2>/dev/null; then
    echo "ALERT: High etcd watchers in ingress-nginx ($WATCHERS) - check polling!"
  else
    echo "ingress-nginx etcd watchers: $WATCHERS"
  fi
fi

# HTTP requests (Prometheus-enabled)
HTTP_RATE=$(query_api "sum(rate(http_requests_total{namespace=\\\"ingress-nginx\\\",job=~\\\"triggeriq.*\\\"}[5m]))")
if [ "$HTTP_RATE" = "null" ]; then
  echo "ERROR: Failed to fetch HTTP rate - check triggeriq Prometheus endpoint (/metrics)"
else
  if (( $(echo "$HTTP_RATE > 100" | bc -l) )); then
    echo "ALERT: High HTTP request rate ($HTTP_RATE req/s) - review scaling!"
  else
    echo "triggeriq HTTP rate: $HTTP_RATE req/s"
  fi
fi
