# k8s-cost-optimizer
Optimize Kubernetes costs on Scaleway Kapsule/Kosmos, with focus on `triggeriq` app.

## Setup
1. Clone: `git clone https://github.com/<your-username>/k8s-cost-optimizer`
2. Install: `kubectl`, `curl`, `jq`
3. Configure Scaleway CLI: `scw init`
4. Set env: `export API_KEY=<your-key> PROJECT_ID=<your-id>`

## Usage
- Deploy HPA: `./scripts/apply-hpa.sh ingress-nginx triggeriq`
- Check metrics: `./scripts/check-metrics.sh $API_KEY $PROJECT_ID my-cluster`
- Grafana: Import `dashboards/cost-optimization.json` to Cockpit.

## Metrics Monitored
- Cluster: `node_cpu_usage_percentage`
- triggeriq: `container_cpu_usage_seconds_total{namespace="ingress-nginx"}`, `http_requests_total`
- Etcd: `kubernetes_cluster_etcdwatcher_namespace_usage{namespace="ingress-nginx"}`

## License
MIT