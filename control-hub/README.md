Introduction
============

The following will help you install StreamSets Control Hub in a k8s
environment.

The examples have the following dependencies:

-   Minikube 0.28+ or existing GKE cluster

-   Helm 2.10

-   Istio 1.0.2

The helm-chart provided for StreamSets Control Hub also includes the
application's database dependencies:

-   MySQL

-   InfluxDB.

Please note these are used simply in a Proof-Of-Concept fashion. No
performance tuning, redundancy, backups etc has been considered.

What you will get after following this
======================================

4 kubernetes pods in default namespace:

[sch-control-hub-one-XXXXXXXXXX-XXXXX] - runs all control
hub applications such as: security, messaging, jobrunner, topology,
notification, policy, provisioning, scheduler, sdp\_classification,
reporting, pipelinestore and sla.

**Note** it is possible to run app instances per container, and the
helm-chart by default does this, but for minikube the example scales
this down.

**[sch-mysql-XXXXXXXXXX-XXXXX -]** persistence store for
applications

**[sch-influxdb-XXXXXXXXXX-XXXXX]** - timeseries database
for statistics

**[system-dc-XXXXXXXXXX-XXXXX]** - system data collector for
pipeline validation

Ability to use browser GUI for control-hub.

Environment setup
=================

Minikube
--------

### Install minikube

Steps here
[https://github.com/kubernetes/minikube](https://github.com/kubernetes/minikube)

### Starting minikube

You maybe familiar with minikube's ability to use various vm-drivers
such as VirtualBox et al. The example below uses hyperkit (Docker for
Mac), but VirtualBox would function just fine.

```
minikube start --vm-driver=hyperkit --memory=8192 --cpus=4 --extra-config=apiserver.authorization-mode=RBAC \
--extra-config=controller-manager.cluster-signing-cert-file="/var/lib/localkube/certs/ca.crt" \
--extra-config=controller-manager.cluster-signing-key-file="/var/lib/localkube/certs/ca.key"

minikube ssh

#This command is entered against the minikube VMs prompt

sudo ip link set docker0 promisc on
netstat -rn | grep 172.17 #Looking for docker0 bridge subnet, usually 172.17/16
# We want a result here, we want to find it.
exit

#This command is entered on the host
netstat -rn | grep 172.17

# We want NO result here. If no result then:
sudo route -n add -net 172.17.0.0/16 `minikube ip`

#Else you may need to shutdown Docker on your host or configure the docker engine in minikube to use a different IPAM than that
# in use on your host for docker0 bridge.

eval \$(minikube docker-env)
```

Helm
----

### Install helm

Please only install, do not init or start helm just yet.
[https://docs.helm.sh/using\_helm/\#installing-helm](https://docs.helm.sh/using_helm/#installing-helm)

Istio
-----

### Download and install Istio

Follow steps at
[https://istio.io/docs/setup/kubernetes/download-release/](https://istio.io/docs/setup/kubernetes/download-release/)
to download.

```
cd <wherever you put istio from step above>/install/kubernetes/helm/

kubectl create -f ./helm-service-account.yaml

helm init \--service-account tiller \--upgrade

helm install -n istio -f <helm-chart-controlhub-repo-path>/docs/control-hub/istio-values.yaml \
--namespace=istio-system ./istio

kubectl label namespace default istio-injection=enabled
```

Installing Control Hub
======================

Verify control hub image availability
-------------------------------------

`docker pull streamsets/control-hub:3.7.0`

Install via helm-chart
----------------------

```
cd <helm-chart-controlhub-repo-path>

helm dependency update

helm install --timeout 600 --namespace default --name sch \
--values <helm-chart-controlhub-repo-path>/docs/control-hub/sch-minikube.yaml control-hub --wait
```
WARNING: This step can take a long time, around 10min on an 2.8 GHz
Intel Core i7

i.e. Macbook Pro 2017.

To monitor progress it is recommended to run

`watch -n1 -d \"kubectl get pod,job,svc\"`

Until you see similar to:
```
NAME                                       READY     STATUS    RESTARTS   AGE
pod/sch-control-hub-one-69f54cc555-qlsp2   3/3       Running   4          26m
pod/sch-influxdb-8644679758-wfdbj          2/2       Running   0          26m
pod/sch-mysql-855fb94f6-pfm2q              1/1       Running   0          26m
pod/system-dc-bc8f59bbf-5nmsd              2/2       Running   0          26m

NAME                                         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)               AGE
service/kubernetes                           ClusterIP   10.96.0.1        <none>        443/TCP               3d
service/sch-control-hub-jobrunner            ClusterIP   10.108.184.125   <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-messaging            ClusterIP   10.102.101.123   <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-notification         ClusterIP   10.101.78.29     <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-pipelinestore        ClusterIP   10.110.251.252   <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-policy               ClusterIP   10.100.185.86    <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-provisioning         ClusterIP   10.104.225.182   <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-reporting            ClusterIP   10.99.85.99      <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-scheduler            ClusterIP   10.103.205.193   <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-sdp-classification   ClusterIP   10.100.86.67     <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-security             ClusterIP   10.101.193.74    <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-sla                  ClusterIP   10.106.77.213    <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-timeseries           ClusterIP   10.97.65.243     <none>        18631/TCP,18632/TCP   26m
service/sch-control-hub-topology             ClusterIP   10.103.155.212   <none>        18631/TCP,18632/TCP   26m
service/sch-influxdb                         ClusterIP   10.101.208.76    <none>        8086/TCP              26m
service/sch-mysql                            ClusterIP   10.102.55.166    <none>        3306/TCP              26m
service/system-dc                            ClusterIP   10.97.237.202    <none>        18630/TCP             26m
```
By way of explanation, every application in control-hub is a
microservice. We create a k8s service per SCH app.

In this case, the deployment has all SCH apps running in one container, but in fact each SCH app can run in its own
deployment pod, and can horizontally scale.

This is configured via the helm chart and the values override, in this case sch-minikube.yaml

From the default `values.yaml`

```
... <snip> ...

appProto: http
apps:
  - name: security
    deployment: security
  - name: pipelinestore
    deployment: pipelinestore
  - name: messaging
    deployment: messaging
... <snip> ...

deployments:
  - name: security
    appsToStart: "security"
    replicaCount: 1
    container:
      env:
        <<: *COMMON_ENV
  - name: pipelinestore
    appsToStart: "pipelinestore"
    replicaCount: 1
    container:
      env:
        <<: *COMMON_ENV
... <snip> ...
```

To explain, each SCH app is defined as a kubernetes service, and the service points to one or more deployments or pods.

The deployment then also needs to know what SCH apps it is responsible for starting.

For instance to have all SCH apps deploy in one deployment or pod:

```
deployments:
- name: one
  appsToStart: "security,messaging,jobrunner,topology,notification,policy,provisioning, \
                scheduler,sdp_classification,reporting,pipelinestore,sla"
  replicaCount: 1
  container:
    env:
      <<: *COMMON_ENV

appProto: http
apps:
- name: security
  deployment: one
- name: pipelinestore
  deployment: one
- name: messaging
  deployment: one
- name: jobrunner
  deployment: one
- name: timeseries
  deployment: one
- name: topology
  deployment: one
- name: notification
  deployment: one
- name: sla
  deployment: one
- name: policy
  deployment: one
- name: provisioning
  deployment: one
- name: scheduler
  deployment: one
- name: sdp_classification
  deployment: one
- name: reporting
  deployment: one
```

Or to have some core applications be in one deployment and others in another:

```
deployments:
- name: one
  appsToStart: "security,messaging,pipelinestore,jobrunner,topology"
  replicaCount: 1
  container:
    env:
      <<: *COMMON_ENV
- name: two
  appsToStart: "notification,policy,provisioning,scheduler,sdp_classification,reporting,sla"
  replicaCount: 1
  container:
    env:
      <<: *COMMON_ENV

appProto: http
apps:
- name: security
  deployment: one
- name: pipelinestore
  deployment: one
- name: messaging
  deployment: one
- name: jobrunner
  deployment: one
- name: timeseries
  deployment: one
- name: topology
  deployment: one
- name: notification
  deployment: two
- name: sla
  deployment: two
- name: policy
  deployment: two
- name: provisioning
  deployment: two
- name: scheduler
  deployment: two
- name: sdp_classification
  deployment: two
- name: reporting
  deployment: two
```

Or to scale one particular SCH app. In this case `pipelinestore` will scale to 3 instances,
while all other SCH apps share a common container:
```
deployments:
- name: one
  appsToStart: "security,messaging,jobrunner,topology,notification,policy, \
                provisioning,scheduler,sdp_classification,reporting,sla"
  replicaCount: 1
  container:
    env:
      <<: *COMMON_ENV
- name: two
  appsToStart: "pipelinestore"
  replicaCount: 3
  container:
    env:
      <<: *COMMON_ENV

appProto: http
apps:
- name: security
  deployment: one
- name: pipelinestore
  deployment: two
- name: messaging
  deployment: one
- name: jobrunner
  deployment: one
- name: timeseries
  deployment: one
- name: topology
  deployment: one
- name: notification
  deployment: one
- name: sla
  deployment: one
- name: policy
  deployment: one
- name: provisioning
  deployment: one
- name: scheduler
  deployment: one
- name: sdp_classification
  deployment: one
- name: reporting
  deployment: one
```

Accessing via browser
---------------------

Get output from`minikube ip`. This is the external IP address of minikube by which to access any services.

Update `/etc/hosts` on the machine running minikube to have an entry for the
ip pointing to <yourname.for.controlhub>. E.g. `sch.minikube.local`

Point browser to: `http://<yourname.for.controlhub>:31380`

Login with username `admin@admin` password `admin@admin`

Delete via helm-chart
---------------------

`helm delete --purge sch`
