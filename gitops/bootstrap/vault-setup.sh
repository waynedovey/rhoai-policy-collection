#!/bin/bash

# setup secrets for gitops
# https://eformat.github.io/rainforest-docs/#/2-platform-work/3-secrets

export VAULT_ROUTE=vault.apps.sno.sandbox2556.opentlc.com
export VAULT_ADDR=https://${VAULT_ROUTE}
export VAULT_SKIP_VERIFY=true

vault login token=${ROOT_TOKEN}

export APP_NAME=vault
export PROJECT_NAME=openshift-gitops
export CLUSTER_DOMAIN=apps.sno.sandbox2556.opentlc.com

vault auth enable -path=$CLUSTER_DOMAIN-${PROJECT_NAME} kubernetes

export MOUNT_ACCESSOR=$(vault auth list -format=json | jq -r ".\"$CLUSTER_DOMAIN-$PROJECT_NAME/\".accessor")

vault policy write $CLUSTER_DOMAIN-$PROJECT_NAME-kv-read -<< EOF
path "kv/data/{{identity.entity.aliases.$MOUNT_ACCESSOR.metadata.service_account_namespace}}/*" {
capabilities=["read","list"]
}
EOF

vault secrets enable -path=kv/ -version=2 kv

vault write auth/$CLUSTER_DOMAIN-$PROJECT_NAME/role/$APP_NAME \
bound_service_account_names=$APP_NAME \
bound_service_account_namespaces=$PROJECT_NAME \
policies=$CLUSTER_DOMAIN-$PROJECT_NAME-kv-read \
period=120s

vault write auth/$CLUSTER_DOMAIN-${PROJECT_NAME}/config \
kubernetes_host="$(oc whoami --show-server)"
