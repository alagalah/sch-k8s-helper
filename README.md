Introduction
============


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
`bash <(curl -Ls https://raw.githubusercontent.com/alagalah/sch-k8s-helper/master/run.sh)`

or clone repository and run:

`./startup.sh`

Example usage:

`SCH_VM_DRIVER=hyperkit ./startup.sh`

Important configuration environment variables:

| Var|Default|Required|
|---|---|---|
|DOCKER_USERNAME|-|Y|
|DOCKER_EMAIL|-|Y|
|DOCKER_PASSWORD|-|Y|
|KUBE_NAMESPACE|default
|SCH_VM_DRIVER|virtualbox
|SCH_VM_RAM|8192
|SCH_VM_CPUS|4

Accessing via browser
---------------------

http://streamsets.minikube.local:31380

username: `admin@admin` 

password: `admin@admin`

Delete via helm-chart
---------------------

`helm delete --purge sch`
