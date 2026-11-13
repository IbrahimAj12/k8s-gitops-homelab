#!/usr/bin/env bash
set -euo pipefail

PVE_HOST="root@100.75.81.69"
CONTROL_LXC="210"
CONTROL_IP="192.168.0.210"
KUBECTL="/usr/local/bin/k3s kubectl"

echo "Starting SSH tunnels to K3s services via Proxmox ($PVE_HOST)..."
echo "  -> ArgoCD UI:       https://localhost:8080"
echo "  -> Grafana UI:      http://localhost:3002"
echo "  -> Online Boutique: http://localhost:8081"
echo "Press Ctrl+C to stop all tunnels."

trap 'kill $(jobs -p) 2>/dev/null || true' EXIT

ssh -L 8080:${CONTROL_IP}:8080 "${PVE_HOST}" \
  "pct exec ${CONTROL_LXC} -- ${KUBECTL} port-forward --address ${CONTROL_IP} svc/argocd-server -n argocd 8080:443" &

ssh -L 3002:${CONTROL_IP}:3002 "${PVE_HOST}" \
  "pct exec ${CONTROL_LXC} -- ${KUBECTL} port-forward --address ${CONTROL_IP} svc/monitoring-grafana -n monitoring 3002:80" &

ssh -L 8081:${CONTROL_IP}:8081 "${PVE_HOST}" \
  "pct exec ${CONTROL_LXC} -- ${KUBECTL} port-forward --address ${CONTROL_IP} svc/frontend -n online-boutique 8081:80" &

wait
