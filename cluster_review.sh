#!/bin/bash

# dependencies:
# - jq
# - omg

################
#### CHECKS #### 

subscriptions() {
# Check ID 1.1 - Subscriptions

## Get clusterID:
echo "Cluster ID:"
omg get clusterversion -o json | jq '.spec.clusterID'

## Channel:
echo "Subscribed channel:"
omg get clusterversion -o json | jq '.spec.channel'

## Cluster Version:
echo "Current cluster version:"
omg get clusterversion -o json | jq '.spec.desiredUpdate.version'
}


master_requirements() {
# Check ID 1.2 - Masters Minimum hardware requirements

## Master Operating System Version
echo "Masters OS Version:"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.name,.status.nodeInfo.osImage'

## Master CPU
echo "Master CPUs:"
omg get nodes -o json | jq  '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.name,.status.allocatable.cpu'

## Masters Memory
echo "Masters Memory:"
omg get nodes -o json | jq  '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.name,.status.allocatable.memory'

## Masters Disk Space
echo "Master disk space (GB):"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.name,(.status.allocatable."ephemeral-storage" | tonumber / 1073741824)'
}


node_requirements() {
# Check ID 1.3 - Workers Minimum hardware requirements

## Worker Operating System Version
echo "Workers OS Version:"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/worker") | .metadata.name,.status.nodeInfo.osImage'

## Worker CPU
echo "Workers CPUs:"
omg get nodes -o json | jq  '.items[] | select(.metadata.labels."node-role.kubernetes.io/worker") | .metadata.name,.status.allocatable.cpu'

## Workers Memory
echo "Workers Memory:"
omg get nodes -o json | jq  '.items[] | select(.metadata.labels."node-role.kubernetes.io/worker") | .metadata.name,.status.allocatable.memory'

## Workers Disk Space
echo "Workers disk space (GB):"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.name,(.status.allocatable."ephemeral-storage" | tonumber / 1073741824)'
}

basic_checks() {
# Check ID 1.4 - Other basic checks

## DNS Configuration
echo "DNS Configuration"
omg get dnses cluster -o json | jq '.spec.baseDomain, .spec.privateZone'

## Shared Network
echo "Cluster Network:"
omg get network/cluster -o json | jq '.spec.clusterNetwork[].cidr'
echo "Nodes IP:"
omg get nodes -o json | jq  '.items[].status.addresses[].address'

## SDN
echo "SDN used:"
omg get network/cluster -o json | jq '.spec.networkType'
}

topology() {
# Check ID 2 - Topology checks

## Consistency
echo "Kernel and container runtime version used by each node:"
omg get nodes -o json | jq '.items[] | .metadata.name, .status.nodeInfo.kernelVersion, .status.nodeInfo.containerRuntimeVersion'

## Number of musters:
echo "Number of masters (HA):"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.name'

## AV Zones Labels
echo "Regions:"
omg get nodes -o json | jq '.items[] | .metadata.labels."topology.kubernetes.io/region"'
echo "Zones:"
omg get nodes -o json | jq '.items[] | .metadata.labels."topology.kubernetes.io/zone"'
}


scalability() {
# Check ID 3 - Scalability

##  HAProxy HA (> 1 router, > 1 infra node)
echo "Infra nodes:"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/infra") | .metadata.name'
echo "Router Pods:"
omg get pods -n openshift-ingress -o json | jq '.items[] | select(.metadata.labels."ingresscontroller.operator.openshift.io/deployment-ingresscontroller"|test("default")) | .metadata.name'

## Number of Nodes
echo "Cluster Network Configuration:"
omg get network/cluster -o json | jq '.spec.clusterNetwork[]'
}


components(){
# Check ID 4 - Component Checks

## Operators health
echo "Cluster Operator statusses"
omg get co

## CRDs
echo "List of CRDs:"
omg get crd

## Master current machine-config
echo "Master machine-config, sync check:"
omg get nodes -o json | jq '.items[] | select(.metadata.labels."node-role.kubernetes.io/master") | .metadata.annotations."machineconfiguration.openshift.io/currentConfig"'

##### TODO etcd checks - based on etcd must-gather
}


registry() {
# Registry:

## Registry pods
echo "Registry pods running:"
omg get pods -n openshift-image-registry -o json | jq '.items[] | select(.metadata.labels."docker-registry") | .metadata.name'

## Registry storage:
echo "Registry storage setup:"
omg get deployments image-registry -n openshift-image-registry -o json  | jq '.spec.template.spec.containers[].env[] | select(.name|test("REGISTRY_STORAGE"))'
}

# Logging

## Regular must-gather does not collect openshift-logging namespace info.. 

monitoring() {
# Monitoring

## Prometheus storage
echo "Prometheus storage:"
omg get statefulset prometheus-k8s -o json -n openshift-monitoring | jq '.spec.template.spec.volumes[] |  select(.name|test("prometheus-k8s-db"))'
}

routing() {
# Routing

## Check routers node selector:
echo "Router node selector:"
omg get pods -n openshift-ingress -o json | jq '.items[] | select(.metadata.labels."ingresscontroller.operator.openshift.io/deployment-ingresscontroller"|test("default")) | .spec.nodeSelector'
}

storage() {
# Storage

## Dynamic storage check:
echo "SC used:"
omg get co storage -o json | jq '.status.relatedObjects[] | select(.resource|test("storageclasses"))'

## SC ot yet collected 
}
######################


if [[ $# -ne 1 ]]; then
    echo "Use: <script.sh> <must_gather_path>"
    exit 2
fi


# list of implemented checks
checks="
subscriptions
master_requirements
node_requirements
basic_checks
topology
scalability
components
registry
monitoring
routing
storage
"


# Use must-gather:
omg use $1

# main loop for calling the check functions
for check in $checks
do
    echo "8<------------------------------------"
    $check
done
