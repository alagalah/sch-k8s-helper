#!/usr/bin/env bash

#If different URL is desired please update ./control-hub/sch-minikube.yaml
#  domain: minikube.local
#  host: streamsets
# 31380 is minikube default for exposing app.

DPM_HOSTNAME=streamsets.minikube.local
DPM_URL=http://${DPM_HOSTNAME}:31380

# test
DPM_CONF_DPM_BASE_URL=${DPM_URL}
. ./sandbox-init.sh
exit 0
# test

echo "Handling base infrastructure"
. ./infrastructure_setup.sh


echo "Installing Control Hub"
. ./install_controlhub.sh

echo "Waiting on healthcheck for control hub..."
source ./healthcheck.sh
callHealthCheck # sourced from healthcheck.sh

echo "Healthy. Access via ${DPM_URL}"

echo "Setting up sandbox org"

DPM_CONF_DPM_BASE_URL=${DPM_URL}
. ./sandbox-init.sh

