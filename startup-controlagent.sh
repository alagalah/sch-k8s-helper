#!/usr/bin/env bash
#
#  Copyright 2018 StreamSets Inc.
#

#######################
# Setup Control Agent #
#######################

# 1. Get a token for Agent from SCH and store it in a secret
AGENT_TOKEN=$(curl -s -X PUT -d "{\"organization\": \"${SCH_ORG}\", \"componentType\" : \"provisioning-agent\", \"numberOfComponents\" : 1, \"active\" : true}" ${DPM_CONF_DPM_APP_SECURITY_URL}/security/rest/v1/organization/${SCH_ORG}/components --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}" | jq '.[0].fullAuthToken')
if [ -z "$AGENT_TOKEN" ]; then
  echo "Failed to generate control agent token."
  echo "Please verify you have Provisioning Operator permissions in SCH"
  exit 1
fi

kubectl create secret generic sch-agent-creds \
    --from-literal=dpm_agent_token_string=${AGENT_TOKEN}

# 2. Create secret for agent to store key pair
kubectl create secret generic compsecret

# 3. Create config map to store configuration referenced by the agent yaml


CONTROL_AGENT_ID=$(uuidgen)
echo ${CONTROL_AGENT_ID} > agent.id
kubectl create configmap streamsets-config \
    --from-literal=org=${SCH_ORG} \
    --from-literal=sch_url=${DPM_INTERNAL_URL} \
    --from-literal=agent_id=${CONTROL_AGENT_ID}

# 4. Launch Agent
cd ${SCRIPT_DIR}
kubectl create -f ./control-agent.yaml

# 5. wait for agent to be registered with SCH
temp_agent_Id=""
while [ -z $temp_agent_Id ]; do
  sleep 10
  temp_agent_Id=$(curl -s -L "${DPM_CONF_DPM_APP_PROVISIONING_URL}/provisioning/rest/v1/dpmAgents?organization=${SCH_ORG}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}" | jq -r ".[] | select(.id==\"${CONTROL_AGENT_ID}\").id")
  echo $temp_agent_Id
done
echo "DPM Agent \"${temp_agent_Id}\" successfully registered with SCH"

