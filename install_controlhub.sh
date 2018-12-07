#!/usr/bin/env bash
#
#  Copyright 2018 StreamSets Inc.
#

function debug_echo {
  if [ $DEBUG -ne 0 ]; then
    echo "***SCH-K8S: $1"
  fi
}

# If debug set, then show command as it executes
if [ ${DEBUG} -ne 0 ]; then
  set -x
fi

#######################
# Install Control Hub #
#######################
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd ${SCRIPT_DIR}
debug_echo "Installing Control Hub at ${SCRIPT_DIR}"\

function install_control_hub() {
  #git clone https://github.com/streamsets/helm-charts.git
  debug_echo "Pulling docker image for control hub"
  docker pull streamsets/control-hub:${SCH_VER}
  debug_echo "Cloning helm-charts"
  git clone /git/work/streamsets/helm-charts
  cd helm-charts
  echo "Installing control-hub. Follow progress: "
  echo "watch -n1 -d \"kubectl get job,pod,svc -n ${KUBE_NAMESPACE}\" "
  helm dependency update control-hub > /dev/null 2>&1
  helm install --timeout 600 --namespace ${KUBE_NAMESPACE} \
  --name sch --values ${SCRIPT_DIR}/control-hub/sch-minikube.yaml control-hub --wait

  cat <<EOF | kubectl create -f -
kind: Service
apiVersion: v1
metadata:
  name: sch-control-hub
  namespace: ${KUBE_NAMESPACE}
spec:
  type: ExternalName
  externalName: ${DPM_HOSTNAME}
EOF

}

helm status sch > /dev/null 2>&1
RC_HELM=$?
# Want an error here, we don't want sch to exist
if [ ${RC_HELM} -ne 0 ]; then
  install_control_hub
else
  echo "SCH already installed in this minikube instance. Try:"
  echo ""
  echo "helm delete --purge sch"
  echo ""
fi


