# k8s-cost-optimizer

Optimize Kubernetes costs on Scaleway Kapsule/Kosmos using HPA and Cockpit metrics.

## Setup

1. Clone: `git clone https://github.com/<your-username>/k8s-cost-optimizer`
2. Install dependencies: `kubectl`, `curl`, `jq`
3. Configure Scaleway CLI: `scw init`
4. Set environment: `export API_KEY=<your-key> PROJECT_ID=<your-id>`

## Usage

- Deploy HPA: `./scripts/apply-hpa.sh default my-app`
- Check metrics: `./scripts/check-metrics.sh $API_KEY $PROJECT_ID my-cluster`
- Import Grafana dashboard: Upload `dashboards/cost-optimization.json` to Cockpit.

## Metrics Monitored

- CPU/Memory: `node_cpu_usage_percentage`, `node_memory_usage_percentage`
- Storage: `kubelet_volume_stats_used_bytes`
- Etcd: `kubernetes_cluster_etcdwatcher_namespace_usage`

## License

MIT