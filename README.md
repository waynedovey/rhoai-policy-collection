# rhoai-policy-collection

## Prerequisite

OpenShift Cluster with cluster-admin access.

## Bootstrap

Installs ArgoCD and ACM

```bash
kustomize build --enable-helm gitops/bootstrap
```

Create htpasswd admin user

```bash
./gitops/bootstrap/users.sh
```

Install LE Certs

```bash
./gitops/bootstrap/certficates.sh
```

Install Extra AWS Storage

```bash
./gitops/bootstrap/storage.sh
```

## Installs Policy Collection for RHOAI

WIP.
