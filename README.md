# Production-Ready Kubernetes GitOps Platform on Proxmox

An end-to-end, Infrastructure-as-Code (IaC) and GitOps-driven Kubernetes platform running on a multi-node **K3s** cluster provisioned over **Proxmox VE** LXC containers. Designed to demonstrate declarative infrastructure provisioning, zero-touch continuous delivery via **ArgoCD**, full-stack observability via **Prometheus & Grafana**, and automated self-healing with measured Mean Time to Recovery (MTTR).

## Architecture Overview

```
                       ┌──────────────────────────────────────────┐
                       │         GitHub (Source of Truth)         │
                       │  github.com/IbrahimAj12/k8s-gitops-homelab│
                       └────────────────────┬─────────────────────┘
                                            │ Git Poll / Sync Loop
                                            ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                         Proxmox VE Host (Private Bridge 192.168.0.0/24)           │
│                                                                                   │
│  ┌──────────────────────────┐  ┌───────────────────────┐  ┌────────────────────┐  │
│  │   k3s-control-1 (LXC)    │  │  k3s-worker-1 (LXC)   │  │ k3s-worker-2 (LXC) │  │
│  │     192.168.0.210        │  │    192.168.0.211      │  │   192.168.0.212    │  │
│  │                          │  │                       │  │                    │  │
│  │ • K3s API Server / etcd  │  │ • Online Boutique     │  │ • Online Boutique  │  │
│  │ • ArgoCD Control Plane   │  │   Microservices       │  │   Microservices    │  │
│  │ • Traefik Ingress        │  │ • Prometheus TSDB     │  │ • Grafana UI       │  │
│  │ • Node Exporter          │  │ • Node Exporter       │  │ • Node Exporter    │  │
│  └──────────────────────────┘  └───────────────────────┘  └────────────────────┘  │
└───────────────────────────────────────────────────────────────────────────────────┘
                                            ▲
                                            │ Encrypted Mesh VPN (Tailscale)
                                            │
                                 ┌──────────┴──────────┐
                                 │  Admin Workstation  │
                                 │  (kubectl / SSH)    │
                                 └─────────────────────┘

```

### Technology Stack

* **Virtualization & Compute:** Proxmox VE hosting 3 Debian 12 LXC containers (`k3s-control-1`, `k3s-worker-1`, `k3s-worker-2`).

* **Infrastructure Provisioning & Configuration:** Terraform (`bpg/proxmox` provider) for declarative LXC lifecycle management + Ansible for kernel module tuning, `/dev/kmsg` mapping, and K3s cluster bootstrapping.

* **Container Orchestration:** K3s (`v1.37.2+k3s1`) with Flannel VXLAN CNI and CoreDNS.

* **GitOps Continuous Delivery:** ArgoCD (`selfHeal: true`, `prune: true`) reconciling application manifests and upstream Helm charts directly from `main`.

* **Workload:** Google Cloud **Online Boutique** (11-tier polyglot microservices e-commerce application + Redis cart store).

* **Observability:** `kube-prometheus-stack` (Prometheus Operator, Prometheus TSDB, Grafana, `kube-state-metrics`, and `node-exporter` DaemonSet) deployed declaratively via ArgoCD Helm values.

* **Remote Access:** Tailscale mesh VPN + SSH local port-forwarding for zero-trust out-of-band administration.

## Repository Structure

```
k8s-gitops-homelab/
├── terraform/                  # Proxmox LXC provisioning (CPU, RAM, networking, cloud-init)
├── ansible/                    # Node preparation & automated K3s control-plane/worker bootstrap
├── gitops/
│   ├── argocd/                 # Declarative ArgoCD Application manifests
│   │   ├── online-boutique.yaml
│   │   └── monitoring-app.yaml # Helm-based kube-prometheus-stack with memory caps
│   └── apps/
│       └── online-boutique/    # Version-controlled Kubernetes Deployments & ClusterIP Services
└── scripts/                    # Operational helpers for cluster lifecycle & local UI tunneling

```

## Key Engineering Decisions & Trade-Offs

1. **Unprivileged/Privileged LXC Kernel Tuning for K3s:**
   Running Kubernetes inside Proxmox LXCs requires explicit cgroup v2 delegation, `overlay` / `br_netfilter` kernel modules, and `/dev/kmsg` device bind-mounts so `kubelet` and `kube-proxy` operate cleanly without full VM hypervisor overhead.

2. **Resource-Bounded Observability on Constrained Nodes:**
   Custom `helm.valuesObject` overrides in `gitops/argocd/monitoring-app.yaml` cap Prometheus memory (`400Mi` request / `800Mi` limit), enforce a 2-day TSDB retention window (`retention: 2d`), and disable unused Alertmanager pods to prevent Linux OOM kills on 2 GB worker nodes.

3. **Server-Side Apply (`ServerSideApply=true`) for Helm CRDs:**
   Enabled `ServerSideApply=true` on the `monitoring` ArgoCD Application so large `kube-prometheus-stack` Custom Resource Definitions bypass Kubernetes' 262 KB `last-applied-configuration` annotation limit.

4. **Raw Manifests vs. Upstream Helm Charts:**
   Application workloads (`online-boutique`) are stored as raw manifests for transparent per-service Git diffs, while third-party infrastructure (`kube-prometheus-stack` v65.1.1) is consumed as a version-pinned Helm chart to avoid vendor manifest bloat.

## Resiliency & Self-Healing Benchmarks (MTTR)

Two controlled chaos experiments were executed against the `online-boutique` namespace to validate automated recovery across both the Kubernetes control plane and ArgoCD's GitOps reconciliation loop:

| Failure Scenario | Recovery Mechanism | Measured MTTR | Result | 
| ----- | ----- | ----- | ----- | 
| **Pod Crash / Termination** (`kubectl delete pod -l app=frontend`) | Kubernetes ReplicaSet Controller detected replica deficit and scheduled replacement pod (`frontend-54b9f9678-dbmld`) | **17.57s** | Zero manual intervention; passed readiness probes | 
| **Configuration Drift / Resource Deletion** (`kubectl delete deployment emailservice`) | ArgoCD detected `OutOfSync` state against Git `main`, re-applied manifest (`selfHeal: true`), and rolled out replacement | **15.90s** | Cluster state automatically reconciled to Git | 

## Quick Start

```
# 1. Provision Proxmox LXCs
cd terraform && terraform apply

# 2. Configure nodes & bootstrap K3s cluster
cd ../ansible && ansible-playbook -i inventory.ini site.yml

# 3. Bootstrap ArgoCD & register GitOps Applications
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f gitops/argocd/online-boutique.yaml
kubectl apply -f gitops/argocd/monitoring-app.yaml

```
---

## Live Platform Observability & GitOps State

### ArgoCD Continuous Reconciliation (`Synced` & `Healthy`)
![ArgoCD Applications Status](docs/argocd-apps.png)

### Grafana Cluster & Microservices Telemetry (`online-boutique`)
![Grafana Namespace Pod Metrics](docs/grafana-monitoring.png)
