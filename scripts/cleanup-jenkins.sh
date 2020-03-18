#!/bin/bash

function getBuildNr(){
  jobUrl=$1
  curl --silent -X POST --user $JENKINS_AUTH $JENKINS_URL/$jobUrl/api/json | jq '.lastBuild.number'
}

function getNextBuildNr(){
  jobUrl=$1
  curl --silent -X POST --user $JENKINS_AUTH $JENKINS_URL/$jobUrl/api/json | jq '.nextBuildNumber'
}

function getBuildState(){
  jobUrl=$1
  buildNr=$2
  curl --silent -X POST --user $JENKINS_AUTH $JENKINS_URL/$jobUrl/$buildNr/api/json | jq '.result' 2>/dev/null
}

function waitForJobStart() {
  jobUrl=$1
  nextBuildNr=$2
  curBuildNr=""
  while [ "$curBuildNr" == "$nextBuildNr" ]; do
    sleep 1
    curBuildNr=$(getBuildNr $jobUrl)
  done
}

function waitForJobEnd() {
  jobUrl=$1
  buildNr=$2
  state=""
  while [ "$state" == "" -o "$state" == "null" ]; do
    sleep 1
    state=$(getBuildState $jobUrl $buildNr)
    echo -n "."
  done
  if [ "$state" != "\"SUCCESS\"" ]; then
    echo " job ended with $state";
    exit 1;
  else
    echo
  fi
}

function buildJob() {
  jobUrl=$1
  echo -n "Running $jobUrl"
  buildNr=$(getNextBuildNr $jobUrl)
  curl --silent -X POST --user $JENKINS_AUTH $JENKINS_URL/$jobUrl/build
  waitForJobStart $jobUrl $buildNr
  waitForJobEnd $jobUrl $buildNr
}

. ./scripts/jenkins-token.env
JENKINS_URL="https://ci-testnet.spacemesh.io/job"

buildJob 'testnet/job/stop-network'
buildJob 'testnet/job/unlock-initdata'
buildJob 'global/job/inventory-initdata'
