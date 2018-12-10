#!/usr/bin/env bash
#
#  Copyright 2018 StreamSets Inc.
#

set -x

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
cat << EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: sch-control-agent
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: sch-control-agent
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      serviceAccountName: streamsets-agent
      hostAliases:
        - ip: "${K8S_IP}"
          hostnames:
          - "${DPM_INTERNAL_HOSTNAME}"
          - "${DPM_HOSTNAME}"
      containers:
      - name: sch-control-agent
        image: streamsets/control-agent:3.7.1
        env:
        - name: HOST
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: dpm_agent_master_url
          value: https://kubernetes.default.svc.cluster.local
        - name: dpm_agent_cof_type
          value: "KUBERNETES"
        - name: dpm_agent_dpm_baseurl
          valueFrom:
            configMapKeyRef:
              name: streamsets-config
              key: sch_url
        - name: dpm_agent_component_id
          valueFrom:
            configMapKeyRef:
              name: streamsets-config
              key: agent_id
        - name: dpm_agent_token_string
          valueFrom:
            secretKeyRef:
              name: sch-agent-creds
              key: dpm_agent_token_string
        - name: dpm_agent_name
          value: sch-control-agent
        - name: dpm_agent_orgId
          valueFrom:
            configMapKeyRef:
              name: streamsets-config
              key: org
        - name: dpm_agent_secret
          value: compsecret
EOF

# 5. wait for agent to be registered with SCH
temp_agent_Id=""
while [ -z $temp_agent_Id ]; do
  sleep 10
  temp_agent_Id=$(curl -s -L "${DPM_CONF_DPM_APP_PROVISIONING_URL}/provisioning/rest/v1/dpmAgents?organization=${SCH_ORG}" --header "Content-Type:application/json" --header "X-Requested-By:SDC" --header "X-SS-REST-CALL:true" --header "X-SS-User-Auth-Token:${DPM_TOKEN}" | jq -r ".[] | select(.id==\"${CONTROL_AGENT_ID}\").id")
  echo $temp_agent_Id
done
echo "DPM Agent \"${temp_agent_Id}\" successfully registered with SCH"

