#!/usr/bin/env bash

SCH_ORG=${SCH_ORG:-sandbox}
SCH_USER=${SCH_USER:-admin@sandbox}
SCH_PASSWORD=${SCH_PASSWORD:-admin@sandbox}
KUBE_NAMESPACE=${KUBE_NAMESPACE:-default}

if [ -z "$DPM_URL" ]; then
  echo "Must specific DPM_URL for control-hub"
  exit 1
fi

DPM_TOKEN=$(curl -s -X POST -d "{\"userName\":\"${SCH_USER}\", \"password\": \"${SCH_PASSWORD}\"}" ${DPM_URL}/security/public-rest/v1/authentication/login --header "Content-Type:application/json" --header "X-Requested-By:SDC" -c - | sed -n '/SS-SSO-LOGIN/p' | perl -lane 'print $F[$#F]')

if [ -z "$DPM_CONF_DPM_APP_PROVISIONING_URL" ]; then
  echo "DPM_CONF_DPM_APP_PROVISIONING_URL being set to $DPM_URL"
  DPM_CONF_DPM_APP_PROVISIONING_URL=$DPM_URL
fi

if [ -z "$DPM_CONF_DPM_APP_SECURITY_URL" ]; then
  echo "DPM_CONF_DPM_APP_SECURITY_URL being set to $DPM_URL"
  DPM_CONF_DPM_APP_SECURITY_URL=$DPM_URL
fi

if [ -z "$DPM_TOKEN" ]; then
  echo "Failed to authenticate with SCH"
  echo "Please check your username, password, and organization name."
  exit 1
fi

# 1. Stop and Delete deployment if one is active
if [[ -f "deployment.id" && -s "deployment.id" ]];
  then
    deployment_id="`cat deployment.id`"
    # Stop deployment
    curl -s -X POST "${DPM_CONF_DPM_APP_PROVISIONING_URL}/provisioning/rest/v1/deployment/${deployment_id}/stop" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}"

    # Wait for deployment to become inactive
    deploymentStatus="ACTIVE"
    while [[ "${deploymentStatus}" != "INACTIVE" ]]; do
      echo "\nCurrent Deployment Status is \"${deploymentStatus}\". Waiting for it to become inactive"
      sleep 10
      deploymentStatus=$(curl -X POST -d "[ \"${deployment_id}\" ]" "${DPM_CONF_DPM_APP_PROVISIONING_URL}/provisioning/rest/v1/deployments/status" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}" | jq -r 'map(select([])|.status)[]')
    done

    # Delete deployment
    curl -s -X DELETE "${DPM_CONF_DPM_APP_PROVISIONING_URL}/provisioning/rest/v1/deployment/${deployment_id}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}"

    rm -f deployment.id
fi

# 2. Delete and Unregister Control Agent if one is active
if [[ -f "agent.id" && -s "agent.id" ]]; then
  agent_id="`cat agent.id`"
  curl -X POST -d "[ \"${agent_id}\" ]" ${DPM_CONF_DPM_APP_SECURITY_URL}/security/rest/v1/organization/${SCH_ORG}/components/deactivate --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}"
  curl -X POST -d "[ \"${agent_id}\" ]" ${DPM_CONF_DPM_APP_SECURITY_URL}/security/rest/v1/organization/${SCH_ORG}/components/delete --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}"
  curl -s -X DELETE "${DPM_CONF_DPM_APP_PROVISIONING_URL}/provisioning/rest/v1/dpmAgent/${agent_id}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}"
  rm -f agent.id
fi

# Set namespace
kubectl config set-context $(kubectl config current-context) --namespace=${KUBE_NAMESPACE}


# Delete agent
kubectl delete -f control-agent.yaml
echo "Deleted control agent"

kubectl delete configmap streamsets-config

# Delete all secrets
kubectl delete secret compsecret sch-agent-creds
echo "Deleted secrets compsecret sch-agent-creds"

kubectl delete rolebinding streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete role streamsets-agent --namespace=${KUBE_NAMESPACE}
kubectl delete serviceaccount streamsets-agent --namespace=${KUBE_NAMESPACE}



