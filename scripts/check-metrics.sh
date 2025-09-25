#!/bin/bash
# Usage: ./check-metrics.sh <COCKPIT_TOKEN> <DATA_SOURCE_ID> <CLUSTER_NAME>

COCKPIT_TOKEN="$1"
DATA_SOURCE_ID="$2"
CLUSTER_NAME="$3"
API_ENDPOINT="https://${DATA_SOURCE_ID}.metrics.cockpit.nl-ams.scw.cloud/prometheus/api/v1/query"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Function to query API and extract the latest value
query_api() {
  local query="$1"
  local response=$(curl -s -X POST "$API_ENDPOINT" \
    -H "Authorization: Bearer $COCKPIT_TOKEN" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "query=$query" 2>&1)
  
  local status=$?
  if [ $status -ne 0 ]; then
    echo "ERROR: curl failed with status $status - check network or endpoint" >&2
    echo "null"
    return
  fi
  
  # Check if response contains error
  if echo "$response" | grep -q '"status":"error"'; then
    local error_msg=$(echo "$response" | jq -r '.error // .errorType // "Unknown error"' 2>/dev/null || echo "API error")
    echo "ERROR: API returned error - $error_msg" >&2
    echo "DEBUG: Query: $query" >&2
    echo "DEBUG: Response: $response" >&2
    echo "null"
    return
  fi
  
  # Extract the latest value
  local result=$(echo "$response" | jq -r '.data.result[0].value[1] // "null"' 2>/dev/null)
  if [ "$result" = "null" ] || [ -z "$result" ]; then
    echo "WARNING: No data found for query: $query" >&2
    echo "null"
  else
    echo "$result"
  fi
}

echo "=== Cluster Metrics for $CLUSTER_NAME ==="

# 1. Cluster CPU usage percentage
CPU_USAGE=$(query_api "100 * (kubernetes_cluster_k8s_shoot_nodes_cpu_usage_total / kubernetes_cluster_k8s_shoot_nodes_cpu_capacity_total)")
if [ "$CPU_USAGE" != "null" ]; then
  CPU_USAGE_ROUNDED=$(printf "%.1f" "$CPU_USAGE")
  if (( $(echo "$CPU_USAGE_ROUNDED < 20" | bc -l 2>/dev/null || echo "1") )); then
    echo "🚨 ALERT: Cluster CPU usage too low ($CPU_USAGE_ROUNDED%) - consider downsizing nodes!"
  else
    echo "✅ Cluster CPU usage: $CPU_USAGE_ROUNDED% (healthy)"
  fi
else
  echo "❌ ERROR: Failed to fetch cluster CPU usage"
fi

# 2. Node count
NODE_COUNT=$(query_api "kubernetes_cluster_k8s_shoot_nodes_ready")
if [ "$NODE_COUNT" != "null" ]; then
  echo "📊 Cluster node count: $NODE_COUNT"
else
  echo "❌ ERROR: Failed to fetch node count"
fi

# 3. Memory usage percentage
MEMORY_USAGE=$(query_api "100 * (kubernetes_cluster_k8s_shoot_nodes_memory_usage_bytes / kubernetes_cluster_k8s_shoot_nodes_memory_capacity_bytes)")
if [ "$MEMORY_USAGE" != "null" ]; then
  MEMORY_USAGE_ROUNDED=$(printf "%.1f" "$MEMORY_USAGE")
  echo "💾 Memory usage: $MEMORY_USAGE_ROUNDED%"
else
  echo "⚠️  Memory usage data unavailable"
fi

# 4. Pod capacity usage
POD_USAGE=$(query_api "100 * (kubernetes_cluster_k8s_shoot_nodes_pods_usage_total / kubernetes_cluster_k8s_shoot_nodes_pods_capacity_total)")
if [ "$POD_USAGE" != "null" ]; then
  POD_USAGE_ROUNDED=$(printf "%.1f" "$POD_USAGE")
  echo "📦 Pod capacity usage: $POD_USAGE_ROUNDED%"
else
  echo "⚠️  Pod usage data unavailable"
fi

# 5. Check if cluster components are healthy
CONTROLPLANE_READY=$(query_api "kubernetes_cluster_k8s_shoot_controlplane_instance_ready")
if [ "$CONTROLPLANE_READY" != "null" ]; then
  if [ "$CONTROLPLANE_READY" = "1" ]; then
    echo "🎯 Control plane: Healthy"
  else
    echo "🚨 Control plane: Unhealthy"
  fi
fi

# 6. Instance-level metrics (node-level CPU)
INSTANCE_CPU=$(query_api "rate(instance_server_cpu_seconds_total[5m]) * 100")
if [ "$INSTANCE_CPU" != "null" ]; then
  INSTANCE_CPU_ROUNDED=$(printf "%.1f" "$INSTANCE_CPU")
  echo "🖥️  Instance CPU (avg): $INSTANCE_CPU_ROUNDED%"
fi

echo "=== Metrics Check Complete ==="

# Summary for Slack/notifications
echo "SUMMARY: CPU:${CPU_USAGE_ROUNDED:-unknown}% | Nodes:${NODE_COUNT:-unknown} | Memory:${MEMORY_USAGE_ROUNDED:-unknown}%"
