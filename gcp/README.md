# Control Hub on Kubernetes (GKE)

This is a quick start to get Control Hub running on GKE.

## Before you begin

You need to have the following:

- Access to GKE with permissions to create a cluster (or use an existing cluster with admin privileges)
- A valid domain name like "harki.stream"
- A valid email service configuration like mailjet or sendgrid
- A docker account that is associated with StreamSets (to access private docker image from dockerhub)

## How to spin up SCH on Kubernetes (GKE)
Run the startup.sh script with the environment variables as shown below:

CREATE_GKE_CLUSTER=1 GKE_CLUSTER_NAME=sch-k8s-test KUBE_NAMESPACE="streamsets" DOCKER_USERNAME="<docker_username>" DOCKER_PASSWORD="docker_password" DOCKER_EMAIL="docker_email" ./startup.sh

The script installs traefik ingress controller. You will see a message that says "Update your hostname.doman to point to : <ip>" once the external endpoint is created. Do as the message says.
  
The installation takes about 15 to 20 minutes (most of which is db creation) after which you can access Control Hub from your browser using adddress "hostname.domain".

## How to destroy SCH on Kubernetes (GKE)
Run the teardown.sh script with environment variables as shown below:

DELETE_GKE_CLUSTER=1 GKE_CLUSTER_NAME=sch-k8s-test KUBE_NAMESPACE="streamsets" DOCKER_USERNAME="<docker_username>" DOCKER_PASSWORD="docker_password" DOCKER_EMAIL="docker_email" ./teardown.sh

