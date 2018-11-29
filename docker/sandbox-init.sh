#!/bin/sh
#
#  Copyright 2018 StreamSets Inc.
#

DPM_ADMIN_USER=${DPM_ADMIN_USER:-admin@admin}
DPM_ADMIN_PASSWORD=${DPM_ADMIN_PASSWORD:-admin@admin}
DPM_CONF_DPM_BASE_URL=${DPM_CONF_DPM_BASE_URL:-http://localhost:18631}
SCRIPT_REPO=${SCRIPT_REPO:-https://raw.githubusercontent.com/alagalah/sch-k8s-helper/}

# Wait until up and running

DPM_URL=${DPM_CONF_DPM_APP_SECURITY_URL:-${DPM_CONF_DPM_BASE_URL}}
echo $DPM_URL

callHealthCheck() {
  HEALTH_CHECK=`curl ${DPM_URL}/public-rest/v1/health`
  until [[ ${HEALTH_CHECK} =~ alive ]]; do
    sleep 5
    HEALTH_CHECK=`curl ${DPM_URL}/public-rest/v1/health`
  done
}

callHealthCheck

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
  exit
fi

callDPM() {
  METHOD=${1:-GET}
  DPM_URL=$2
  URL_PATH=$3
  DATA=${4:-""}
  REST=$5
  curl \
    -X $METHOD \
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

# Create a new Org (Sandbox)
callDPM "PUT" ${DPM_URL} "security/rest/v1/organizations" \
  '{"organization":{"id":"sandbox","name":"Sandbox","primaryAdminId":"admin@sandbox","active":true,"passwordExpiryTimeInMillis":9999999999,"validDomains":"*"},"organizationAdminUser":{"id":"admin@sandbox","organization":"sandbox","name":"Sandbox Admin","email":"admin@sandbox.com","roles":["user","org-admin","datacollector:admin","pipelinestore:pipelineEditor","jobrunner:operator","timeseries:reader","timeseries:writer","topology:editor","notification:user","sla:editor","provisioning:operator"],"active":true}}'

# Add all roles to the new user added
callDPM "POST" ${DPM_URL} "security/rest/v1/organization/sandbox/user/admin@sandbox" \
  '{"id":"admin@sandbox","organization":"sandbox","name":"Sandbox Admin","email":"admin@sandbox.com","roles":["timeseries:reader","org-admin","timeseries:writer","datacollector:admin","jobrunner:operator","pipelinestore:pipelineEditor","topology:editor","sla:editor","provisioning:operator","user","notification:user","auth-token-admin","datacollector:guest","pipelinestore:user","scheduler:operator","sla:user","topology:user","reporting:operator","policy:manager","pipelinestore:rulesEditor","org-user","datacollector:manager","datacollector:creator","classification:admin"],"groups":["all@sandbox"],"active":true,"passwordExpiryTime":9942382589646,"creator":"admin@admin","createdOn":1537198348948,"lastModifiedBy":"admin@admin","lastModifiedOn":1537198348948,"destroyer":null,"deleteTime":0,"userDeleted":false,"nameInOrg":"admin@sandbox","passwordGenerated":false}'

DPM_TOKEN=`curl -X POST \
  -d "{\"userName\":\"admin@sandbox\", \"password\": \"admin@sandbox\"}" \
  --header "Content-Type:application/json" \
  --header "X-Requested-By:SDC" \
  --silent \
  --output /dev/null \
  --cookie-jar - \
  $DPM_URL/security/public-rest/v1/authentication/login \
  | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]' `

# Get the directory the script is from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

echo ${SCRIPT_DIR}

echo "Obtaining pipeline zip files."
curl -Ls ${SCRIPT_REPO}/master/sdc.zip -o sdc.zip
curl -Ls ${SCRIPT_REPO}/master/sdc.zip -o sdc.zip



DPM_URL=${DPM_CONF_DPM_APP_PIPELINESTORE_URL:-${DPM_CONF_DPM_BASE_URL}}

callHealthCheck

echo "Adding pipelines via API"
# Add pipeline
callDPM2 "POST" ${DPM_URL} "pipelinestore/rest/v1/pipelines/importPipelineCommits" \
  "file=@${SCRIPT_DIR}/sdc.zip"


# Add pipeline
callDPM2 "POST" ${DPM_URL} "pipelinestore/rest/v1/pipelines/importPipelineCommits" \
  "file=@${SCRIPT_DIR}/sdce.zip"

echo "Done"