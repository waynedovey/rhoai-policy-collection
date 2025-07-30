#!/bin/bash

set -o pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[38;5;214m'
readonly NC='\033[0m' # No Color
readonly RUN_DIR=$(pwd)

ENVIRONMENT=${ENVIRONMENT:-sno}
BASE_DOMAIN=${BASE_DOMAIN:-}
CLUSTER_NAME=${CLUSTER_NAME:-}

wait_for_openshift_api() {
    local i=0
    HOST=https://api.${CLUSTER_NAME}.${BASE_DOMAIN}:6443/healthz
    until [ $(curl -k -s -o /dev/null -w %{http_code} ${HOST}) = "200" ]
    do
        echo -e "${GREEN}Waiting for 200 response from openshift api ${HOST}.${NC}"
        sleep 5
        ((i=i+1))
        if [ $i -gt 100 ]; then
            echo -e "🕱${RED}Failed - OpenShift api ${HOST} never ready?.${NC}"
            exit 1
        fi
    done
    echo "🌴 wait_for_openshift_api ran OK"
}

check_done() {
    echo "🌴 Running check_done..."
    STATUS=$(oc get node -l cred-manager/node-configured  | wc -l)

    if [ "$STATUS" -gt 0 ]; then
        echo "🌴 masters already cert-rolled, no need to redo - check_done ran OK"
        return 0
    fi

    echo -e "💀${ORANGE}Warn - check_done not done for cert-roll, continuing ${NC}"
    return 1
}

roll_certs() {
    echo "🌴 Running roll_certs..."

    # output certs - will be valid 24hr if new cluster
    oc describe secret/csr-signer -n openshift-kube-controller-manager-operator
    
    # roll certs on masters only
    oc apply -f kubelet-bootstrap-cred-manager-ds.yaml

    # wait_for_pod_done
    sleep 60

    # delete signer secrets
    oc delete secrets/csr-signer-signer secrets/csr-signer -n openshift-kube-controller-manager-operator

    # clusteroperators roll kubeapi and others
    oc adm wait-for-stable-cluster --minimum-stable-period=45s --timeout=5m

    # output new certs - should be 30 day ones now
    oc describe secret/csr-signer -n openshift-kube-controller-manager-operator
}

usage() {
  cat <<EOF 2>&1
usage: $0 [ -d ]

Roll the 24hr install cluster signing certs post install so we get the 30day certs and can stop the cluster straight away after install.
EOF
  exit 1
}

all() {
    if check_done; then return; fi

    wait_for_openshift_api
    roll_certs
}

while getopts opts; do
  case $opts in
    *)
      usage
      ;;
  esac
done


[ -z "$BASE_DOMAIN" ] && echo "🕱 Error: must supply BASE_DOMAIN in env" && exit 1
[ -z "$CLUSTER_NAME" ] && echo "🕱 Error: must supply CLUSTER_NAME in env" && exit 1

echo "🌴 BASE_DOMAIN set to $BASE_DOMAIN"
echo "🌴 CLUSTER_NAME set to $CLUSTER_NAME"

all

echo -e "\n🌻${GREEN}Cert Roll ended OK.${NC}🌻\n"
exit 0