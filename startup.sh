#!/usr/bin/env bash
#
#  Copyright 2018 StreamSets Inc.
#

# Get the directory the script is from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"


#If different URL is desired please update ./control-hub/sch-minikube.yaml
#  domain: minikube.local
#  host: streamsets
# 31380 is minikube default for exposing app.

# Optional params and their defaults
DEBUG=${DEBUG:-0}
KUBE_NAMESPACE=${KUBE_NAMESPACE:-default}
SCH_VM_DRIVER=${SCH_VM_DRIVER:-hyperkit}
KUBE_USERNAME=${KUBE_USERNAME:-minikube}
SCH_VER=${SCH_VER:-3.7.0}
DPM_HOSTNAME=${DPM_HOSTNAME:-streamsets.minikube.local}
DPM_URL=http://${DPM_HOSTNAME}:31380
SCH_SANDBOX=${SCH_SANDBOX:-0}

# Fun story, but internally to k8s, no one knows your local /etc/hosts or DNS. For this will map a
# externalname (outside URL) to this service name, in effect resolving
# to an outside address that forces the SDC to come from the outside in to the cluster to access SCH.
# ie svc: sch.default.svc.cluster.local -> maps outside -> streamsets.minikube.local -> maps /etc/hosts -> 192.168.64.8
DPM_INTERNAL_URL="http://sch-control-hub.${KUBE_NAMESPACE}.svc.cluster.local:31380"
DPM_CONF_DPM_APP_PROVISIONING_URL=${DPM_CONF_DPM_APP_PROVISIONING_URL:-${DPM_INTERNAL_URL}}
DPM_CONF_DPM_APP_SECURITY_URL=${DPM_CONF_DPM_APP_PROVISIONING_URL:-${DPM_INTERNAL_URL}}
DPM_CONF_DPM_BASE_URL=${DPM_URL}

START=`date +%s`

echo "Handling base infrastructure"
TASK=`date +%s`
. ./startup-infrastructure.sh
cd ${SCRIPT_DIR}
echo " took:" $((`date +%s`-TASK)) "s"

echo "Installing Control Hub"
TASK=`date +%s`
. ./install_controlhub.sh
cd ${SCRIPT_DIR}
echo " took:" $((`date +%s`-TASK)) "s"

echo "Waiting on healthcheck for control hub..."
TASK=`date +%s`
source ./util-healthcheck.sh
cd ${SCRIPT_DIR}
callHealthCheck # sourced from util-healthcheck.sh
echo "Healthy. Access via ${DPM_URL}"
echo " took:" $((`date +%s`-TASK)) "s"


if [[ ${SCH_SANDBOX} -ne 0 ]]; then
  echo "Setting up sandbox org"
  TASK=`date +%s`
  DPM_CONF_DPM_BASE_URL=${DPM_URL}
  . ./configure-sandbox.sh
  cd ${SCRIPT_DIR}
  echo " took:" $((`date +%s`-TASK)) "s"
fi

echo "Script took:" $((`date +%s`-START)) "s"

