#!/usr/bin/env bash

KUBE_NAMESPACE=${KUBE_NAMESPACE:-default}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd ${SCRIPT_DIR}

kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

kubectl delete rolebinding streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete role streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete clusterrolebinding cluster-admin-binding

helm delete --purge sch
kubectl delete namespace ${KUBE_NAMESPACE}


