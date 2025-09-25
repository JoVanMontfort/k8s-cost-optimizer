#!/bin/bash
# Usage: ./check-metrics.sh <COCKPIT_TOKEN> <DATA_SOURCE_ID> <CLUSTER_NAME>

COCKPIT_TOKEN="$1"
DATA_SOURCE_ID="$2"
CLUSTER_NAME="$3"
API_ENDPOINT="https://${DATA_SOURCE_ID}.metrics.cockpit.nl-ams.scw.cloud/prometheus/api/v1/query_range"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Function to query API and log raw response with headers
query_api() {
  local query="$1"
  local response=$(curl -s -i -X POST "$API_ENDPOINT" \
    -H "Authorization: Bearer $COCKPIT_TOKEN" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "query=$query" \
    --data-urlencode "start=$START" \
    --data-urlencode "end=$END" \
    --data-urlencode "step=300s")
  local status=$?
  if [ $status -ne 0 ]; then
    echo "ERROR: curl failed with status $status - check network or endpoint ($API_ENDPOINT)" >&2
    echo "null"
  elif echo "$response" | grep -q 'HTTP/1.1 400\|HTTP/2 400'; then
    echo "ERROR: API returned 400 - check query syntax: $query" >&2
    echo "DEBUG: Full response with headers: $response" >&2
    echo "null"
  elif echo "$response" | grep -q 'HTTP/1.1 404\|HTTP/2 404'; then
    echo "ERROR: API returned 404 - check metric name, Cockpit setup, or data source ID ($DATA_SOURCE_ID)" >&2
    echo "DEBUG: Full response with headers: $response" >&2
    echo "null"
  else
    echo "DEBUG: Query: $query" >&2
    echo "DEBUG: Full response with headers: $response" >&2
    local result=$(echo "$response" | sed '1,/^$/d' | jq '.data.result[0].values[-1][1] // "null"' | tr -d '"')
    if [ -z "$result" ] || [ "$result" = "null" ]; then
      echo "ERROR: Query returned empty result: $query" >&2
      echo "null"
    else
      echo "$result"
    fi
  fi
}

# Cluster-wide CPU usage
CPU=$(query_api "100 * (kubernetes_cluster_k8s_shoot_nodes_cpu_usage_total{resource_name=~'$CLUSTER_NAME'} / kubernetes_cluster_k8s_shoot_nodes_cpu_capacity_total{resource_name=~'$CLUSTER_NAME'})")
if [ "$CPU" = "null" ]; then
  echo "ERROR: Failed to fetch cluster CPU usage - check COCKPIT_TOKEN, DATA_SOURCE_ID, or Cockpit setup"
else
  if (( $(echo "$CPU < 20" | bc -l) )); then
    echo "ALERT: Cluster CPU usage too low ($CPU%) - consider downsizing nodes!"
  else
    echo "Cluster CPU usage: $CPU% (healthy)"
  fi
fi

# triggeriq pod CPU (unavailable)
echo "ERROR: triggeriq CPU unavailable - enable Metrics Server for container_cpu_usage_seconds_total"

# Node count
NODE_COUNT=$(query_api "kubernetes_cluster_k8s_shoot_nodes_ready{resource_name=~'$CLUSTER_NAME'}")
if [ "$NODE_COUNT" = "null" ]; then
  echo "ERROR: Failed to fetch node count - check Cockpit metrics"
else
  echo "Cluster node count: $NODE_COUNT"
fi

# HTTP requests (unavailable)
echo "ERROR: triggeriq HTTP rate unavailable - enable NGINX Ingress Prometheus metrics"
