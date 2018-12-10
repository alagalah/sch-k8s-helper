#!/usr/bin/env bash

KUBE_NAMESPACE=${KUBE_NAMESPACE:-default}
#If different URL is desired please update ./control-hub/sch-minikube.yaml
#  domain: minikube.local
#  host: streamsets
# 31380 is minikube default for exposing app.

# Optional params and their defaults
DEBUG=${DEBUG:-0}
KUBE_NAMESPACE=${KUBE_NAMESPACE:-default}
KUBE_USERNAME=${KUBE_USERNAME:-minikube}

SCH_VM_DRIVER=${SCH_VM_DRIVER:-hyperkit}
SCH_VM_RAM=${SCH_VM_RAM:-8192}
SCH_VM_CPUS=${SCH_VM_CPUS:-4}

SCH_VER=${SCH_VER:-3.7.0}
DPM_HOSTNAME=${DPM_HOSTNAME:-streamsets.minikube.local}
DPM_URL=http://${DPM_HOSTNAME}:31380
SCH_SANDBOX=${SCH_SANDBOX:-0}

# Fun story, but internally to k8s, no one knows your local /etc/hosts or DNS. For this will map a
# externalname (outside URL) to this service name, in effect resolving
# to an outside address that forces the SDC to come from the outside in to the cluster to access SCH.
# ie svc: sch.default.svc.cluster.local -> maps outside -> streamsets.minikube.local -> maps /etc/hosts -> 192.168.64.8
DPM_INTERNAL_HOSTNAME={$DPM_INTERNAL_HOSTNAME:-"http://sch-control-hub.${KUBE_NAMESPACE}.svc.cluster.local"}
DPM_INTERNAL_URL=${DPM_INTERNAL_URL:-"${DPM_INTERNAL_HOSTNAME}:31380"}
DPM_CONF_DPM_APP_PROVISIONING_URL=${DPM_CONF_DPM_APP_PROVISIONING_URL:-${DPM_INTERNAL_URL}}
DPM_CONF_DPM_APP_SECURITY_URL=${DPM_CONF_DPM_APP_SECURITY_URL:-${DPM_INTERNAL_URL}}
DPM_CONF_DPM_BASE_URL=${DPM_URL}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd ${SCRIPT_DIR}

. ./teardown-controlagent.sh

kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

kubectl delete rolebinding streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete role streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete clusterrolebinding cluster-admin-binding

helm delete --purge sch
kubectl delete namespace ${KUBE_NAMESPACE}


