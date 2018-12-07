#!/bin/sh

: ${GKE_CLUSTER_NAME:="streamsets-quickstart"}

kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

# Configure & Delete traefik service
kubectl delete -f traefik-dep.yaml
echo "Deleted traefik ingress controller and service"

# Delete traefik configuration to handle https
kubectl delete configmap traefik-conf
echo "Deleted configmap traefik-conf"

# Delete all secrets
kubectl delete secret traefik-cert

# Delete the certificate and key file
rm -f tls.crt tls.key

kubectl delete rolebinding streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete role streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete clusterrolebinding traefik-ingress-controller
kubectl delete clusterrole traefik-ingress-controller
kubectl delete serviceaccount traefik-ingress-controller
kubectl delete clusterrolebinding cluster-admin-binding

kubectl delete namespace ${KUBE_NAMESPACE}
echo "Deleted Namespace ${KUBE_NAMESPACE}"

if [ -n "$DELETE_GKE_CLUSTER" ]; then
  gcloud container clusters delete ${GKE_CLUSTER_NAME} --zone "us-central1-a"
fi
