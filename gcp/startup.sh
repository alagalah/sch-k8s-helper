#!/bin/sh

function show_usage {
  echo "\nVariables can be exported or set on the command line as shown below. Requires helm to be installed on your machine."
  echo '[CREATE_GKE_CLUSTER=1, GKE_CLUSTER_NAME="sch-cluster"] KUBE_NAMESPACE="streamsets" ./startup.sh'
  echo '-----------------------------------------------------------------------'
}

######################
# Create GKE Cluster #
######################

: ${GKE_CLUSTER_NAME:="streamsets-quickstart"}
if [ -n "$CREATE_GKE_CLUSTER" ]; then
  # if set, this will also attempt to run the gcloud command to provision a cluster
  gcloud container clusters create "${GKE_CLUSTER_NAME}" \
    --zone "us-central1-a" \
    --machine-type "n1-standard-1" \
    --image-type "COS" \
    --disk-size "100" \
    --num-nodes "5" \
    --network "default" \
    --enable-cloud-logging \
    --enable-cloud-monitoring

  gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}"
fi

# Set the namespace
kubectl create namespace ${KUBE_NAMESPACE}
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

########################################################################
# Setup Service Account with roles to read required kubernetes objects #
########################################################################

GCP_IAM_USERNAME=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user="$GCP_IAM_USERNAME"

kubectl create serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl create role streamsets-agent \
    --verb=get,list,create,update,delete,patch \
    --resource=pods,secrets,replicasets,deployments,ingresses,services,horizontalpodautoscalers \
    --namespace=${KUBE_NAMESPACE}
kubectl create rolebinding streamsets-agent \
    --role=streamsets-agent \
    --serviceaccount=${KUBE_NAMESPACE}:streamsets-agent \
    --namespace=${KUBE_NAMESPACE}

kubectl create serviceaccount traefik-ingress-controller
kubectl create clusterrole traefik-ingress-controller \
    --verb=get,list,watch \
    --resource=endpoints,ingresses.extensions,services,secrets
kubectl create clusterrolebinding traefik-ingress-controller \
    --clusterrole=traefik-ingress-controller \
    --serviceaccount=${KUBE_NAMESPACE}:traefik-ingress-controller

####################################
# Setup Traefik Ingress Controller #
####################################

# 1. Generate self signed certificate and create a secret
openssl req -newkey rsa:2048 \
    -nodes \
    -keyout tls.key \
    -x509 \
    -days 365 \
    -out tls.crt \
    -subj "/C=US/ST=California/L=San Francisco/O=My Company/CN=mycompany.com"
kubectl create secret generic traefik-cert \
    --from-file=tls.crt \
    --from-file=tls.key

# 2. Create traefik configuration to handle https
kubectl create configmap traefik-conf --from-file=traefik.toml

# 3. Configure & create traefik service
kubectl create -f traefik-dep.yaml --namespace=${KUBE_NAMESPACE}

# 4. Wait for an external endpoint to be assigned
# external_ip=""
# while [ -z $external_ip ]; do
#     sleep 10
#     external_ip=$(kubectl get svc traefik-ingress-service -o json | jq -r 'select(.status.loadBalancer.ingress != null) | .status.loadBalancer.ingress[].ip')
# done
# echo "External Endpoint to Access Authoring SDC : ${external_ip}\n"
# echo "Update your hostname.doman to point to : ${external_ip}\n"

#######################
# Install Control Hub #
#######################

helm init --wait
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --upgrade --wait
helm repo add streamsets https://streamsets.github.io/helm-charts/
helm repo update


# Create secret to pull image from docker registry
kubectl create secret docker-registry regcred \
 --docker-server='https://index.docker.io/v1/' \
 --docker-username=${DOCKER_USERNAME} \
 --docker-password=${DOCKER_PASSWORD} \
 --docker-email=${DOCKER_EMAIL}

