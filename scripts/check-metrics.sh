#!/bin/bash
# Requires: curl, jq
# Usage: ./check-metrics.sh <API_KEY> <PROJECT_ID> <CLUSTER_NAME>

API_KEY="$1"
PROJECT_ID="$2"
CLUSTER_NAME="$3"
START=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)
END=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# CPU usage per node
curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
  -H "X-Auth-Token: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Project: $PROJECT_ID" \
  -d "{\"type\":\"metrics\",\"query\":\"avg by (node) (node_cpu_usage_percentage{cluster_name=~\\\"$CLUSTER_NAME\\\"})\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}" \
  | jq '.data.result[] | "\(.metric.node): \(.values[-1][1])%"'

# Etcd watchers per namespace
curl -s -X POST "https://api.scaleway.com/cockpit/v1/query" \
  -H "X-Auth-Token: $API_KEY" \
  -H "Content-Type: application/json" \
  -H "Project: $PROJECT_ID" \
  -d "{\"type\":\"metrics\",\"query\":\"sum by (namespace) (kubernetes_cluster_etcdwatcher_namespace_usage{cluster_name=~\\\"$CLUSTER_NAME\\\"})\",\"start\":\"$START\",\"end\":\"$END\",\"step\":\"5m\"}" \
  | jq '.data.result[] | "\(.metric.namespace): \(.values[-1][1]) watchers"'