#!/bin/bash

set -exv

IMAGE_NAME="quay.io/cloudservices/autotune"
ADDITIONAL_TAGS="qa latest"
AUTOTUNE_DOCKERFILE="Dockerfile.autotune"
AUTOTUNE_GIT_DIR="autotune"
AUTOTUNE_GIT_DIR_PATH="$PWD/$AUTOTUNE_GIT_DIR"
AUTOTUNE_GIT_BRANCH="remote_monitoring"

if [[ -z "$QUAY_USER" || -z "$QUAY_TOKEN" ]]; then
    echo "QUAY_USER and QUAY_TOKEN must be set"
    exit 1
fi

if [[ -z "$RH_REGISTRY_USER" || -z "$RH_REGISTRY_TOKEN" ]]; then
    echo "RH_REGISTRY_USER and RH_REGISTRY_TOKEN  must be set"
    exit 1
fi

echo $CURRENT_IMAGE_TAG

mkdir -p $AUTOTUNE_GIT_DIR_PATH
git clone --branch $AUTOTUNE_GIT_BRANCH https://github.com/kruize/autotune.git $AUTOTUNE_GIT_DIR_PATH

pushd $AUTOTUNE_GIT_DIR
IMAGE_TAG=$(git rev-parse --short=7 HEAD)

# Create tmp dir to store data in during job run (do NOT store in $WORKSPACE)
export TMP_JOB_DIR=$(mktemp -d -p "$HOME" -t "jenkins-${JOB_NAME}-${BUILD_NUMBER}-XXXXXX")
echo "job tmp dir location: $TMP_JOB_DIR"

function job_cleanup() {
    echo "cleaning up job tmp dir: $TMP_JOB_DIR"
    rm -fr $TMP_JOB_DIR
}

trap job_cleanup EXIT ERR SIGINT SIGTERM

DOCKER_CONF="$TMP_JOB_DIR/.docker"
mkdir -p "$DOCKER_CONF"
docker --config="$DOCKER_CONF" login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io
docker --config="$DOCKER_CONF" login -u="$RH_REGISTRY_USER" -p="$RH_REGISTRY_TOKEN" registry.redhat.io
docker --config="$DOCKER_CONF" build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f ${AUTOTUNE_DOCKERFILE} .
docker --config="$DOCKER_CONF" push "${IMAGE_NAME}:${IMAGE_TAG}"

for ADDITIONAL_TAG in $ADDITIONAL_TAGS; do
    docker --config="$DOCKER_CONF" tag "${IMAGE_NAME}:${IMAGE_TAG}" "${IMAGE_NAME}:${ADDITIONAL_TAG}"
    docker --config="$DOCKER_CONF" push "${IMAGE_NAME}:${ADDITIONAL_TAG}"
done

popd

rm -fr $AUTOTUNE_GIT_DIR_PATH