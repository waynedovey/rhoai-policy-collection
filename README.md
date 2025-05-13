# rhoai-policy-collection

OLM v0,1 support for RHOAI Clusters.

This repo is using [SNO on SPOT](https://github.com/eformat/sno-for-100) in AWS with a g6 NVIDIA instance as an example accelerated infrastructure.

## Prerequisite

OpenShift Cluster with cluster-admin access. See SNO on SPOT using:

```bash
export INSTANCE_TYPE=g6.8xlarge
export ROOT_VOLUME_SIZE=400
export OPENSHIFT_VERSION=4.18.10
```

## Bootstrap

Installs ArgoCD and ACM

```bash
kustomize build --enable-helm gitops/bootstrap | oc apply -f-
```

Create CR's

```bash
oc apply -f gitops/bootstrap/setup-cr.yaml
```

We keep Auth, PKI, Storage separate for now as these are Infra specific.

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

## Setup app-of-apps storage

With only `storage.yaml` in the app-of-apps folder:

```bash
oc apply -f gitops/app-of-apps/sno-app-of-apps.yaml
```

And set SC default

```bash
oc annotate sc/lvms-vgsno storageclass.kubernetes.io/is-default-class=true
oc annotate sc/gp3-csi storageclass.kubernetes.io/is-default-class-
```

This uses the default storage we setup for LVM

## Vault Secrets

Install `vault.yaml` in the app-of-apps folder.

## Installs Policy Collection for RHOAI

WIP - base `rhoai` DSC currently.
