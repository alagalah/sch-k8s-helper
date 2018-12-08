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
  minikube start --vm-driver=${SCH_VM_DRIVER} --memory=8192 --cpus=4
}

function debug_echo() {
  if [ $DEBUG -ne 0 ]; then
    echo "***SCH-K8S: $1"
  fi
}

function removehost() {
    ETC_HOSTS=/etc/hosts
    HOSTNAME=$1
    if [ -n "$(grep ${HOSTNAME} ${ETC_HOSTS})" ]
    then
        echo "${HOSTNAME} Found in your ${ETC_HOSTS}, Removing now...";
        sudo sed -i".bak" "/${HOSTNAME}/d" ${ETC_HOSTS}
    else
        echo "${HOSTNAME} was not found in your ${ETC_HOSTS}";
    fi
}

function addhost() {
    ETC_HOSTS=/etc/hosts
    HOSTNAME=$1
    IP=$2
    HOSTS_LINE="${IP}\t${HOSTNAME}"
    if [ -n "$(grep ${HOSTNAME} ${ETC_HOSTS})" ]
        then
            echo "${HOSTNAME} already exists : $(grep ${HOSTNAME} ${ETC_HOSTS})"
        else
            echo "Adding ${HOSTNAME} to your ${ETC_HOSTS}";
            sudo -- sh -c -e "echo '${HOSTS_LINE}' >> ${ETC_HOSTS}";

            if [ -n "$(grep ${HOSTNAME} ${ETC_HOSTS})" ]
                then
                    echo "$(HOSTNAME) was added succesfully \n $(grep ${HOSTNAME} ${ETC_HOSTS})";
                else
                    echo "Failed to Add $(HOSTNAME), Try again!";
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
  echo "Error: minikube is not running."
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

kubectl create namespace ${KUBE_NAMESPACE}
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}

kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user="$KUBE_USERNAME"

kubectl create serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE}

kubectl create role streamsets-agent \
    --verb=get,list,create,patch,update,delete \
    --resource=pods,secrets,deployments,services \
    --namespace=${KUBE_NAMESPACE}
kubectl create rolebinding streamsets-agent \
    --role=streamsets-agent \
    --serviceaccount=${KUBE_NAMESPACE}:streamsets-agent \
    --namespace=${KUBE_NAMESPACE}

# Create secret to pull image from docker registry
eval $(minikube docker-env)
kubectl create secret docker-registry regcred \
 --docker-server='https://index.docker.io/v1/' \
 --docker-username=${DOCKER_USERNAME} \
 --docker-password=${DOCKER_PASSWORD} \
 --docker-email=${DOCKER_EMAIL}

#######################################################################################
#
#  ISTIO INSTALL
#
#
#######################################################################################

function istio_install() {
  cd ${SCRIPT_DIR}
  curl -L https://git.io/getLatestIstio | sh -
  cd `find . -name "istio-1.*" -type d`
  cd install/kubernetes/helm/
  kubectl create -f ./helm-service-account.yaml
  helm init --service-account tiller --upgrade
  sleep 5
  helm install -n istio -f ${SCRIPT_DIR}/control-hub/istio-values.yaml --namespace=istio-system ./istio
  sleep 10
  kubectl label namespace default istio-injection=enabled
}

helm status istio > /dev/null 2>&1
ISTIO_RC=$?
if [ $ISTIO_RC -eq 0 ]; then
  echo "Istio already installed, using installation."
else
  istio_install
fi


##############
#
#   ETC/HOSTS
#
##############

# Eventually Service Discovery will handle this.
# TODO: Need better way of handling this, but for minikube on PC will suffice

MINIKUBE_IP=$(minikube ip)

removehost ${DPM_HOSTNAME}
removehost "datacollector-deployment.${KUBE_NAMESPACE}.svc.cluster.local"
removehost "sch-control-hub.${KUBE_NAMESPACE}.svc.cluster.local"

addhost ${DPM_HOSTNAME} ${MINIKUBE_IP}
addhost "datacollector-deployment.${KUBE_NAMESPACE}.svc.cluster.local" ${MINIKUBE_IP}
addhost "sch-control-hub.${KUBE_NAMESPACE}.svc.cluster.local" ${MINIKUBE_IP}



