#!/usr/bin/env bash
trap 'kill $(jobs -p) 2>/dev/null' EXIT

kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &
kubectl port-forward svc/frontend -n online-boutique 8081:80 >/dev/null 2>&1 &
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 >/dev/null 2>&1 &

echo "ArgoCD: https://localhost:8080 | Shop: http://localhost:8081 | Grafana: http://localhost:3000"
echo "Press Ctrl+C to stop."
wait
