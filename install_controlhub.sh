#!/usr/bin/env bash

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
debug_echo "Installing Control Hub at ${SCRIPT_DIR}"
helm status sch > /dev/null 2>&1
RC_HELM=$?
# Want an error here, we don't want sch to exist
if [ ${RC_HELM} -eq 0 ]; then
  echo "SCH already installed in this minikube instance. Try:"
  echo ""
  echo "helm delete --purge sch"
  echo ""
  exit 1
fi
#git clone https://github.com/streamsets/helm-charts.git
debug_echo "Pulling docker image for control hub"
docker pull streamsets/control-hub:${SCH_VER}
debug_echo "Cloning helm-charts"
git clone /git/work/streamsets/helm-charts
cd helm-charts
echo "Installing control-hub. Follow progress: "
echo "watch -n1 -d \"kubectl get job,pod,svc\" "
helm dependency update control-hub > /dev/null 2>&1
helm install --timeout 600 --namespace ${KUBE_NAMESPACE} \
--name sch --values ${SCRIPT_DIR}/control-hub/sch-minikube.yaml control-hub --wait

