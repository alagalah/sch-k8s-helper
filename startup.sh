#!/usr/bin/env bash

#If different URL is desired please update ./control-hub/sch-minikube.yaml
#  domain: minikube.local
#  host: streamsets
# 31380 is minikube default for exposing app.

DPM_HOSTNAME=streamsets.minikube.local

echo "Handling base infrastructure"
DPM_HOSTNAME=${DPM_HOSTNAME} ./infrastructure_setup.sh

DPM_URL=http://${DPM_HOSTNAME}:31380
echo "Installing Control Hub"
DPM_URL=${DPM_URL} ./install_controlhub.sh