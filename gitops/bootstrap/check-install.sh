#!/bin/bash

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly ORANGE='\033[38;5;214m'
readonly NC='\033[0m' # No Color

check_pods_allocatable() {
    echo "🌴 Running check_pods_allocatable..."
    local i=0
    PODS=$(oc get $(oc get node -o name -l node-role.kubernetes.io/master=) -o=jsonpath={.status.allocatable.pods})
    until [ "$PODS" == 500 ]
    do
        echo -e "${GREEN}Waiting for pods $PODS to equal 500.${NC}"
        ((i=i+1))
        if [ $i -gt 200 ]; then
            echo -e "🕱${RED}Failed - node allocatable pods wrong - $PODS?.${NC}"
            exit 1
        fi
        sleep 10
        PODS=$(oc get $(oc get node -o name -l node-role.kubernetes.io/master=) -o=jsonpath={.status.allocatable.pods})
    done
    echo "🌴 check_pods_allocatable $PODS ran OK"
}

check_gpus_allocatable() {
    echo "🌴 Running check_gpus_allocatable..."
    local i=0
    GPUS=$(oc get $(oc get node -o name -l node-role.kubernetes.io/master=) -o=jsonpath={.status.allocatable.nvidia\\.com\\/gpu})
    until [ "$GPUS" == 8 ]
    do
        echo -e "${GREEN}Waiting for gpus $GPUS to equal 8.${NC}"
        ((i=i+1))
        if [ $i -gt 200 ]; then
            echo -e "🕱${RED}Failed - node allocatable gpus wrong - $GPUS?.${NC}"
            exit 1
        fi
        sleep 10
        GPUS=$(oc get $(oc get node -o name -l node-role.kubernetes.io/master=) -o=jsonpath={.status.allocatable.nvidia\\.com\\/gpu})
    done
    echo "🌴 check_gpus_allocatable $GPUS ran OK"
}

check_llm_pods() {
    echo "🌴 Running check_llm_pods..."
    local i=0
    PODS=$(oc get pods -n llama-serving | grep -e Running | wc -l)
    until [ "$PODS" == 2 ]
    do
        echo -e "${GREEN}Waiting for llm pods $PODS to equal 2.${NC}"
        ((i=i+1))
        if [ $i -gt 200 ]; then
            echo -e "🕱${RED}Failed - llm pods wrong - $PODS?.${NC}"
            exit 1
        fi
        sleep 10
        GPUS=$(oc get $(oc get node -o name -l node-role.kubernetes.io/master=) -o=jsonpath={.status.allocatable.nvidia\\.com\\/gpu})
    done
    echo "🌴 check_llm_pods $PODS ran OK"
}

check_pods_allocatable
check_gpus_allocatable
check_llm_pods

echo -e "\n🌻${GREEN}Check Install ended OK.${NC}🌻\n"
exit 0
