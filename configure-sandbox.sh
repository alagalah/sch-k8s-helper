#!/usr/bin/env bash
#
#  Copyright 2018 StreamSets Inc.
#


#######################################################################################
#
#  Setup all the state
#
#
#######################################################################################

DEBUG=${DEBUG:-0}

function debug_echo {
  if [ $DEBUG -ne 0 ]; then
    echo "***SCH-K8S: $1"
  fi
}

# If debug set, then show command as it executes
if [ ${DEBUG} -ne 0 ]; then
  set -x
fi


DPM_ADMIN_USER=${DPM_ADMIN_USER:-admin@admin}
DPM_ADMIN_PASSWORD=${DPM_ADMIN_PASSWORD:-admin@admin}
DPM_CONF_DPM_BASE_URL=${DPM_CONF_DPM_BASE_URL:-http://localhost:18631}

# Wait until up and running

DPM_URL=${DPM_CONF_DPM_APP_SECURITY_URL:-${DPM_CONF_DPM_BASE_URL}}

source util-healthcheck.sh
callHealthCheck # sourced from util-healthcheck.sh

# Following courtesy of Pasindhu's
DPM_TOKEN=`curl --connect-timeout 900 -X POST \
  -d "{\"userName\":\"$DPM_ADMIN_USER\", \"password\": \"$DPM_ADMIN_PASSWORD\"}" \
  --header "Content-Type:application/json" \
  --header "X-Requested-By:SDC" \
  --silent \
  --output /dev/null \
  --cookie-jar - \
  $DPM_URL/security/public-rest/v1/authentication/login \
  | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]' `


if [ -z "$DPM_TOKEN" ]
then
  echo "Username or the password is incorrect";
  exit 1
fi

callDPM() {
  METHOD=${1:-GET}
  DPM_URL=$2
  URL_PATH=$3
  DATA=${4:-""}
  REST=$5
  curl \
    -X $METHOD \
    --silent \
    -H "X-SS-User-Auth-Token:$DPM_TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'X-Requested-By: SCH UI' \
    --data-binary "$DATA" \
    $REST \
    "$DPM_URL/$URL_PATH"
}

callDPM2() {
  METHOD=${1:-GET}
  DPM_URL=$2
  URL_PATH=$3
  DATA=${4:-""}
  REST=$5
  curl \
    -X $METHOD \
    --silent \
    -H "X-SS-User-Auth-Token:$DPM_TOKEN" \
    -H 'Content-Type: multipart/form-data' \
    -H 'X-Requested-By: SCH UI' \
    -H 'Accept-Encoding: gzip, deflate' \
    -F "$DATA" \
    $REST \
    "$DPM_URL/$URL_PATH"
}

DPM_URL=${DPM_CONF_DPM_APP_SECURITY_URL:-${DPM_CONF_DPM_BASE_URL}}

callHealthCheck

#######################################################################################
#
#  Create users and org for Sandbox
#
#######################################################################################
SCH_ORG=${SCH_ORG:-sandbox}
SCH_USER=${SCH_USER:-admin@sandbox}
SCH_PASSWORD=${SCH_PASSWORD:-admin@sandbox}

# Create a new Org (Sandbox)
callDPM "PUT" ${DPM_URL} "security/rest/v1/organizations" \
  '{"organization":{"id":"sandbox","name":"Sandbox","primaryAdminId":"admin@sandbox","active":true,"passwordExpiryTimeInMillis":9999999999,"validDomains":"*"},"organizationAdminUser":{"id":"admin@sandbox","organization":"sandbox","name":"Sandbox Admin","email":"admin@sandbox.com","roles":["user","org-admin","datacollector:admin","pipelinestore:pipelineEditor","jobrunner:operator","timeseries:reader","timeseries:writer","topology:editor","notification:user","sla:editor","provisioning:operator"],"active":true}}'

# Add all roles to the new user added
callDPM "POST" ${DPM_URL} "security/rest/v1/organization/sandbox/user/admin@sandbox" \
  '{"id":"admin@sandbox","organization":"sandbox","name":"Sandbox Admin","email":"admin@sandbox.com","roles":["timeseries:reader","org-admin","timeseries:writer","datacollector:admin","jobrunner:operator","pipelinestore:pipelineEditor","topology:editor","sla:editor","provisioning:operator","user","notification:user","auth-token-admin","datacollector:guest","pipelinestore:user","scheduler:operator","sla:user","topology:user","reporting:operator","policy:manager","pipelinestore:rulesEditor","org-user","datacollector:manager","datacollector:creator","classification:admin"],"groups":["all@sandbox"],"active":true,"passwordExpiryTime":1543382589646,"creator":"admin@admin","createdOn":1537198348948,"lastModifiedBy":"admin@admin","lastModifiedOn":1537198348948,"destroyer":null,"deleteTime":0,"userDeleted":false,"nameInOrg":"admin@sandbox","passwordGenerated":false}'

#######################################################################################
#
#  Add sample pipelines
#
#######################################################################################

DPM_TOKEN=`curl -X POST \
  -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" \
  --header "Content-Type:application/json" \
  --header "X-Requested-By:SDC" \
  --silent \
  --output /dev/null \
  --cookie-jar - \
  $DPM_URL/security/public-rest/v1/authentication/login \
  | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]' `



DPM_URL=${DPM_CONF_DPM_APP_PIPELINESTORE_URL:-${DPM_CONF_DPM_BASE_URL}}

callHealthCheck

echo "Adding pipelines via API"
# Add pipelines from ZIP
callDPM2 "POST" ${DPM_URL} "pipelinestore/rest/v1/pipelines/importPipelineCommits" \
  "file=@${SCRIPT_DIR}/sdc.zip" > /dev/null 2>&1


# Add pipelines from ZIP
callDPM2 "POST" ${DPM_URL} "pipelinestore/rest/v1/pipelines/importPipelineCommits" \
  "file=@${SCRIPT_DIR}/sdce.zip" > /dev/null 2>&1


#######################################################################################
#
#  Services and routing
#
#######################################################################################
# Create service so that references internally to say sch.default.svc.cluster.local point to
# a DNS entry for "control hub" say streamsets.minikube.local
#cat <<EOF | kubectl create -f -
#kind: Service
#apiVersion: v1
#metadata:
#  name: sch-control-hub
#  namespace: ${KUBE_NAMESPACE}
#spec:
#  type: ExternalName
#  externalName: ${DPM_HOSTNAME}
#EOF


#######################################################################################
#
#  Deploy Control Agent
#
#######################################################################################
#debug_echo "Calling startup-controlagent.sh"
#. ./startup-controlagent.sh

#######################################################################################
#
#  Setup routing etc for authoring datacollector for sandbox org
#
#######################################################################################

#######################################################################################
#
#  Call Control Hub API to create datacollector deployment
#
#######################################################################################

echo "Sandbox org created. Access via username:admin@sandbox password:admin@sandbox"