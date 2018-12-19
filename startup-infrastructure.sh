#!/usr/bin/env bash

#######################################################################################
#
#  Setup all the state
#
#
#######################################################################################

function show_usage() {
  echo "Variables can be exported or set on the command line as shown below."
  echo ""
  echo 'DEBUG=1 SCH_VM_DRIVER=hyperkit KUBE_NAMESPACE="streamsets" ./startup.sh'
  echo '-----------------------------------------------------------------------'
}


if [ -z "$DOCKER_USERNAME" ]; then
  show_usage
  echo "Error: Please give a DOCKER_USERNAME that can access the StreamSets images"
  exit 1
fi

if [ -z "$DOCKER_PASSWORD" ]; then
  show_usage
  echo "Error: Please give a DOCKER_PASSWORD for user:${DOCKER_USERNAME} that can access the StreamSets images"
  exit 1
fi

if [ -z "$DOCKER_EMAIL" ]; then
  show_usage
  echo "Error: Please give the DOCKER_EMAIL for user:${DOCKER_USERNAME} that can access the StreamSets images"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

function validate_command() {
  if ! [ -x "$(command -v $1)" ]; then
    echo "Error: $1 is not installed." >&2
    shift
    echo $@
    exit 1
  fi
}

function start_minikube() {
  echo "Starting minikube"
  minikube start --vm-driver=${SCH_VM_DRIVER} --memory=${SCH_VM_RAM} \--cpus=${SCH_VM_CPUS} > /dev/null 2>&1

  # Expect to see 13 pods in Running state in namespace kube-system before moving on.
  waitForPodCount "Running" "kube-system" 11
  waitForPodReady "kube-system"
  echo "Minikube started successfully."
}

function debug_echo() {
  if [ $DEBUG -ne 0 ]; then
    echo "***SCH-K8S: $1"
  fi
}

function removehost() {
    ETC_HOSTS=/etc/hosts
    ETC_HOSTNAME=$1
    if [ -n "$(grep ${ETC_HOSTNAME} ${ETC_HOSTS})" ]
    then
        debug_echo "${ETC_HOSTNAME} Found in your ${ETC_HOSTS}, Removing now...";
        sudo sed -i".bak" "/${ETC_HOSTNAME}/d" ${ETC_HOSTS}
    else
        debug_echo "${ETC_HOSTNAME} was not found in your ${ETC_HOSTS}";
    fi
}

function addhost() {
    ETC_HOSTS=/etc/hosts
    ETC_HOSTNAME=$1
    IP=$2
    HOSTS_LINE="${IP}\t${ETC_HOSTNAME}"
    if [ -n "$(grep ${ETC_HOSTNAME} ${ETC_HOSTS})" ]
        then
            debug_echo "${ETC_HOSTNAME} already exists : $(grep ${ETC_HOSTNAME} ${ETC_HOSTS})"
        else
            debug_echo "Adding ${ETC_HOSTNAME} to your ${ETC_HOSTS}";
            sudo -- sh -c -e "echo '${HOSTS_LINE}' >> ${ETC_HOSTS}";

            if [ -n "$(grep ${ETC_HOSTNAME} ${ETC_HOSTS})" ]
                then
                    echo "Added to ${ETC_HOSTS}: $(grep ${ETC_HOSTNAME} ${ETC_HOSTS})"
                else
                    echo "Failed to Add ${ETC_HOSTNAME}, Exitting.";
                    exit 1
            fi
    fi
}

# If debug set, then show command as it executes
if [ ${DEBUG} -ne 0 ]; then
  set -x
fi


#
# Validate pre-requisites are installed
#

# Helper text. Call a function to make sure a command exists, and what to do if it doesn't.
INSTALL_HELM="Please see instructions at: https://docs.helm.sh/using_helm/#installing-helm"
INSTALL_MINIKUBE="Please see instructions at: https://github.com/kubernetes/minikube"
INSTALL_GIT="Please install git."
INSTALL_ISTIO="Follow steps at https://istio.io/docs/setup/kubernetes/download-release/ to download."
INSTALL_KUBECTL="Follow steps at https://kubernetes.io/docs/tasks/tools/install-kubectl/"
INSTALL_JQ="Please install jq via appropriate installer for your platform."
INSTALL_SCH_DRIVER="SCH_VM_DRIVER=${SCH_VM_DRIVER} is not known on this system. Please consult valid options for your system."

validate_command "minikube" $INSTALL_MINIKUBE
[[ ${SCH_VM_DRIVER} -ne "none" ]] && validate_command $SCH_VM_DRIVER $INSTALL_SCH_DRIVER
validate_command "helm" $INSTALL_HELM
validate_command "git" INSTALL_GIT
validate_command "kubectl" $INSTALL_KUBECTL
validate_command "jq" $INSTALL_JQ


##################
#
#  MINIKUBE checks
#
##################

# Check minikube status
debug_echo "Checking minikube status"
minikube status > /dev/null 2>&1
RC_MINIKUBE=$?
if [ ${RC_MINIKUBE} -ne 0 ]; then
  echo "Warning: minikube is not running."
  start_minikube
fi

eval $(minikube docker-env)

# SSH into minikube and execute commands
## Want promiscuous mode for traffic
debug_echo "Setting promiscuous mode for minikube VM docker0 bridge"
echo "sudo ip link set docker0 promisc on; exit" | minikube ssh > /dev/null 2>&1

## Want to be able to route back to minikube via names, which means routes
debug_echo "Checking 172.17 route on minikube for docker0"
ROUTE_EXISTS=$(echo "netstat -rn; exit" | minikube ssh | grep 172.17)
if [ -z "$ROUTE_EXISTS" ]; then
  echo "Could not find route 172.17 for docker0 in minikube, aborting."
  exit 1
fi

echo "sudo -- sh -c -e \"echo '127.0.1.1 ${DPM_HOSTNAME}' >> /etc/hosts\"; exit " | minikube ssh > /dev/null 2>&1
echo "sudo -- sh -c -e \"echo '127.0.1.1 ${DPM_INTERNAL_HOSTNAME}' >> /etc/hosts\"; exit " | minikube ssh > /dev/null 2>&1

kubectl create namespace ${KUBE_NAMESPACE} > /dev/null 2>&1
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE} > /dev/null 2>&1

kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user="$KUBE_USERNAME" > /dev/null 2>&1

kubectl create serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE} > /dev/null 2>&1

kubectl create role streamsets-agent \
    --verb=get,list,create,patch,update,delete \
    --resource=pods,secrets,deployments,services \
    --namespace=${KUBE_NAMESPACE} > /dev/null 2>&1

kubectl create rolebinding streamsets-agent \
    --role=streamsets-agent \
    --serviceaccount=${KUBE_NAMESPACE}:streamsets-agent \
    --namespace=${KUBE_NAMESPACE} > /dev/null 2>&1

# Create secret to pull image from docker registry
kubectl create secret docker-registry regcred \
 --docker-server='https://index.docker.io/v1/' \
 --docker-username=${DOCKER_USERNAME} \
 --docker-password=${DOCKER_PASSWORD} \
 --docker-email=${DOCKER_EMAIL} > /dev/null 2>&1

#######################################################################################
#
#  ISTIO INSTALL
#
#
#######################################################################################

minikube addons enable ingress
helm init
waitForPodReady "kube-system"

#function istio_install() {
#  cd ${SCRIPT_DIR}
#  #If it exists, use it, if it doesn't, get it and use it.
#  ls istio-1.* > /dev/null 2>&1 || curl -sL https://git.io/getLatestIstio | sh - > /dev/null 2>&1 &&   cd `find . -name "istio-1.*" -type d`
#  kubectl apply -f install/kubernetes/helm/helm-service-account.yaml
#  helm init --service-account tiller
#  echo "Waiting for tiller..."
#  waitForPodCount "Running" "kube-system" 14
#  waitForPodReady "kube-system"
#  echo "Installing Istio"
#  helm install --wait -n istio -f ${SCRIPT_DIR}/control-hub/istio-values.yaml --namespace=istio-system install/kubernetes/helm/istio
#
#  kubectl label namespace default istio-injection=enabled
#}
#
#echo "Checking Istio."
#helm status istio > /dev/null 2>&1
#ISTIO_RC=$?
#if [ $ISTIO_RC -eq 0 ]; then
#  echo "Istio already installed, using installation."
#else
#  istio_install
#fi


##############
#
#   ETC/HOSTS
#
##############

# Eventually Service Discovery will handle this.
# TODO: Need better way of handling this, but for minikube on PC will suffice

K8S_IP=$(minikube ip)

echo "Adding host entries"
removehost ${DPM_HOSTNAME}
removehost "datacollector-deployment.${KUBE_NAMESPACE}.svc.cluster.local"
removehost "sch-control-hub.${KUBE_NAMESPACE}.svc.cluster.local"

addhost ${DPM_HOSTNAME} ${K8S_IP}
addhost "datacollector-deployment.${KUBE_NAMESPACE}.svc.cluster.local" ${K8S_IP}
addhost "sch-control-hub.${KUBE_NAMESPACE}.svc.cluster.local" ${K8S_IP}



