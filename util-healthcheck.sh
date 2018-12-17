#!/usr/bin/env bash
#
#  Copyright 2018 StreamSets Inc.
#

DPM_URL=${DPM_URL:-http://localhost:18631}

function callHealthCheck() {
  HEALTH_CHECK=`curl -s ${DPM_URL}/public-rest/v1/health`
  HEALTH_CHECK=${HEALTH_CHECK:-dead}
  until [[ ${HEALTH_CHECK} =~ alive ]]; do
    sleep 10
    HEALTH_CHECK=`curl -s ${DPM_URL}/public-rest/v1/health`
    HEALTH_CHECK=${HEALTH_CHECK:-dead}
  done
}

