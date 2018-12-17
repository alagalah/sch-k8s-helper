#!/usr/bin/env bash

function usage() {
  echo "
    Returns number of pods in namespace for status.

    $1 = STATUS [default=NULL (all)]
    $2 = NAMESPACE [default=-all-namespaces]
  "
}

function podStatusCount() {
  STATUS=${1:-all}
  NAMESPACE=${2:-all}

  if [[ ${STATUS} == "-h" ]]; then
    usage
    exit 0
  fi

  STATUS_CMD=""
  if [[ ${STATUS} -ne "all" ]]; then
    STATUS_CMD="--field-selector=status.phase=${STATUS}"
  fi

  NAMESPACE_CMD="--all-namespaces"
  if [[ ${STATUS} -ne "all" ]]; then
    NAMESPACE_CMD="-n ${NAMESPACE}"
  fi

  echo `kubectl get pods ${NAMESPACE_CMD} ${STATUS_CMD} | wc -l`
}

function podAllReady() {
  NAMESPACE=${1:-all}

  NAMESPACE_CMD="--all-namespaces"
  if [[ ${STATUS} -ne "all" ]]; then
    NAMESPACE_CMD="-n ${NAMESPACE}"
  fi

  echo `kubectl get pods ${NAMESPACE_CMD} | grep -vE '1/1|2/2|3/3' | wc -l`
}

function waitForPodCount() {
  STATUS=$1
  NAMESPACE=$2
  EXPECTED_COUNT=$3
  TIMEOUT=${4:-10} #Wait 10min by default then die. Can extend if needed via $4
  TIMEOUT_LOOPS=$((TIMEOUT*2))
  PODCOUNT=$(podStatusCount ${STATUS} ${NAMESPACE})
  echo "${PODCOUNT}/${EXPECTED_COUNT} pods with ${STATUS} in ${NAMESPACE}"
  DEADMAN=0
  until [[ ${PODCOUNT} -eq ${EXPECTED_COUNT} ]]; do
    sleep 30
    DEADMAN=$((DEADMAN+1))
    PODCOUNT=$(podStatusCount ${STATUS} ${NAMESPACE})
    echo "${PODCOUNT}/${EXPECTED_COUNT} pods with ${STATUS} in ${NAMESPACE}"
    if [[ "${DEADMAN}" -gt "${TIMEOUT_LOOPS}" ]]; then
       echo "waitForPodCount status=${STATUS} namespace=${NAMESPACE} expectedcount=${EXPECTED_COUNT} current=${PODCOUNT} took 10min. Its dead, Jim."
       exit 1
    fi
  done

}

function waitForPodReady() {
  NAMESPACE=$1
  TIMEOUT=${2:-10} #Wait 10min by default then die. Can extend if needed via $4
  TIMEOUT_LOOPS=$((TIMEOUT*2))
  PODCOUNT=$(podAllReady ${NAMESPACE})
  EXPECTED_COUNT=1 #header
  echo "$((PODCOUNT-EXPECTED_COUNT)) pods not ready in ${NAMESPACE}"
  DEADMAN=0
  until [[ ${PODCOUNT} -eq ${EXPECTED_COUNT} ]]; do
    sleep 10
    DEADMAN=$((DEADMAN+1))
    PODCOUNT=$(podStatusCount ${STATUS} ${NAMESPACE})
  echo "$((PODCOUNT-EXPECTED_COUNT)) pods not ready in ${NAMESPACE}"
    if [[ "${DEADMAN}" > "${TIMEOUT_LOOPS}" ]]; then
       echo "waitForPodReady namespace=${NAMESPACE} waiting for $((PODCOUNT-EXPECTED_COUNT)) pods took ${TIMEOUT} min. Its dead, Jim."
       exit 1
    fi
  done

}