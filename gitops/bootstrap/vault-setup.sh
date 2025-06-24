#!/bin/bash

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[38;5;214m'
readonly NC='\033[0m' # No Color

# setup secrets for gitops
# https://eformat.github.io/rainforest-docs/#/2-platform-work/3-secrets

# use login
export KUBECONFIG=~/.kube/config.${AWS_PROFILE}

login () {
    echo "💥 Login to OpenShift..." | tee -a output.log
    local i=0
    oc login -u admin -p ${ADMIN_PASSWORD} --server=https://api.sno.${BASE_DOMAIN}:6443
    until [ "$?" == 0 ]
    do
        echo -e "${GREEN}Waiting for 0 rc from oc commands.${NC}" 2>&1 | tee -a output.log
        ((i=i+1))
        if [ $i -gt 100 ]; then
            echo -e "🕱${RED}Failed - oc login never ready?.${NC}" 2>&1 | tee -a output.log
            exit 1
        fi
        sleep 10
        oc login -u admin -p ${ADMIN_PASSWORD} --server=https://api.sno.${BASE_DOMAIN}:6443
    done
    echo "💥 Login to OpenShift Done" | tee -a output.log
}
login

check_done() {
    echo "🌴 Running check_done..."
    STATUS=$(oc -n vault get $(oc get pods -n vault -l app.kubernetes.io/instance=vault -o name) -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [ "$STATUS" != "True" ]; then
      echo -e "💀${ORANGE}Warn - check_done not ready for vault, continuing ${NC}"
      return 1
    else
      echo "🌴 check_done ran OK"
    fi
    return 0
}

if check_done; then
    echo -e "\n🌻${GREEN}Vault setup OK.${NC}🌻\n"
    exit 0;
fi

init () {
    echo "💥 Init Vault..." | tee -a output.log
    local i=0
    oc -n vault exec vault-0 -- vault operator init -key-threshold=1 -key-shares=1 -tls-skip-verify 2>&1 | tee /tmp/vault-init
    until [ "$?" == 0 ]
    do
        echo -e "${GREEN}Waiting for 0 rc from oc commands.${NC}"
        ((i=i+1))
        if [ $i -gt 100 ]; then
            echo -e "🕱${RED}Failed - oc login never ready?.${NC}"
            exit 1
        fi
        sleep 10
        oc -n vault exec vault-0 -- vault operator init -key-threshold=1 -key-shares=1 -tls-skip-verify 2>&1 | tee /tmp/vault-init
    done
    echo "💥 Init Vault Done" | tee -a output.log
}
init

export UNSEAL_KEY=$(cat /tmp/vault-init | grep -e 'Unseal Key 1' | awk '{print $4}')
export ROOT_TOKEN=$(cat /tmp/vault-init | grep -e 'Initial Root Token' | awk '{print $4}')

oc -n vault exec vault-0 -- vault operator unseal -tls-skip-verify $UNSEAL_KEY
if [ "$?" != 0 ]; then
    echo -e "🕱${RED}Failed - to unseal vault ?${NC}"
    exit 1
fi

export VAULT_ROUTE=vault-vault.apps.sno.${BASE_DOMAIN}
export VAULT_ADDR=https://${VAULT_ROUTE}
export VAULT_SKIP_VERIFY=true

vault login token=${ROOT_TOKEN}
if [ "$?" != 0 ]; then
    echo -e "🕱${RED}Failed - to login to vault ?${NC}"
    exit 1
fi

export APP_NAME=vault
export PROJECT_NAME=openshift-gitops
export CLUSTER_DOMAIN=apps.sno.${BASE_DOMAIN}

vault auth enable -path=$CLUSTER_DOMAIN-${PROJECT_NAME} kubernetes

export MOUNT_ACCESSOR=$(vault auth list -format=json | jq -r ".\"$CLUSTER_DOMAIN-$PROJECT_NAME/\".accessor")

vault policy write $CLUSTER_DOMAIN-$PROJECT_NAME-kv-read -<< EOF
path "kv/data/ocp/sno/*" {
capabilities=["read","list"]
}
EOF

vault secrets enable -path=kv/ -version=2 kv

vault write auth/$CLUSTER_DOMAIN-$PROJECT_NAME/role/$APP_NAME \
bound_service_account_names=$APP_NAME \
bound_service_account_namespaces=$PROJECT_NAME \
policies=$CLUSTER_DOMAIN-$PROJECT_NAME-kv-read \
period=120s

CA_CRT=$(openssl s_client -showcerts -connect api.sno.${BASE_DOMAIN}:6443 2>&1 | awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/ {print $0}')

vault write auth/$CLUSTER_DOMAIN-${PROJECT_NAME}/config \
kubernetes_host="$(oc whoami --show-server)" \
kubernetes_ca_cert="$CA_CRT"

ansible-vault decrypt secrets/vault-sno --vault-password-file <(echo "$ANSIBLE_VAULT_SECRET")
sh secrets/vault-sno $ROOT_TOKEN
ansible-vault encrypt secrets/vault-sno --vault-password-file <(echo "$ANSIBLE_VAULT_SECRET")

echo -e "\n🌻${GREEN}Vault setup OK.${NC}🌻\n"
exit 0