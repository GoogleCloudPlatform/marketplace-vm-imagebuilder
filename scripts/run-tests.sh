#!/bin/bash -eu
#
# Copyright 2018 Google LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and

# Ensure all required env vars are supplied.
for var in SOLUTION_NAME PACKER_SSH_USERNAME ZONE PRE_IMAGE USE_INTERNAL_IP TESTS_DIR; do
  if ! [[ -v "${var}" ]]; then
    echo "${var} env variable is required"
    exit 1
  fi
done

if ! [[ -f "${TESTS_DIR}/run-tests-on-instance.sh" ]]; then
  echo "ERROR: Expected executable bash script at ${TESTS_DIR}/run-tests-on-instance.sh was not found."
  exit 1
fi

# User to be created on a test instance.
export USER="${USER:-imagebuilder}"

# Custom metadata for a test instance.
# Each metadata entry is a key/value pair separated by an equals sign.
# Multiple arguments can be passed and has to be separated by a comma.
readonly TESTS_CUSTOM_METADATA="${TESTS_CUSTOM_METADATA:-}"

readonly INSTANCE="imagebuilder-tests-${PRE_IMAGE}-${RANDOM}"
# $IMAGEBUILDER_TEST_DIR: temporary dir on vm.
readonly IMAGEBUILDER_TEST_DIR=$(mktemp --dry-run /tmp/imagebuilder-tests.XXXXXX)

# $TEMPDIR: temporary dir on machine which this script is executed.
readonly TEMPDIR="$(mktemp -d)"
readonly SSH_KEY="${TEMPDIR}/id_rsa"
readonly PRIVATE_SSH_KEY="${SSH_KEY}"
readonly PUBLIC_SSH_KEY="${SSH_KEY}.pub"

echo "==> Starting imagebuilder tests ..."

echo "--> Generates a new SSH key pair ..."
ssh-keygen -P '' -t rsa -b 4096 -f "${SSH_KEY}"

echo "--> Creating a temporary instance (${INSTANCE}) ..."
gcloud_output="$(gcloud compute instances create "${INSTANCE}" \
  --image="${PRE_IMAGE}" \
  --zone="${ZONE}" \
  --description="New instance created by imagebuilder tests" \
  --metadata=block-project-ssh-keys=true,ssh-keys="${USER}:$(cat "${PUBLIC_SSH_KEY}")","${TESTS_CUSTOM_METADATA}" \
  --machine-type=n1-standard-1 \
  --labels=auto=test \
  --tags=imagebuilder-workers \
  --format=text)"

readonly EXTERNAL_IP="$(echo "${gcloud_output}" | awk '/^networkInterfaces\[0\]\.accessConfigs\[0\]\.natIP:/ { print $2 }')"
readonly INTERNAL_IP="$(echo "${gcloud_output}" | awk '/^networkInterfaces\[0\]\.networkIP:/ { print $2 }')"
unset gcloud_output

echo "INTERNAL_IP: ${INTERNAL_IP}"
echo "EXTERNAL_IP: ${EXTERNAL_IP}"

if [[ "${USE_INTERNAL_IP}" != true ]]; then
  readonly IP="${EXTERNAL_IP}"
else
  readonly IP="${INTERNAL_IP}"
fi

echo "--> Waiting until SSH is available (${INSTANCE}) ..."
declare -i index=1
declare -ir max_connection_attempts=12
while (( ${index} <= ${max_connection_attempts} )); do
  ssh -q \
      -i "${PRIVATE_SSH_KEY}" \
      -o UserKnownHostsFile="${TEMPDIR}/known_hosts" \
      -o StrictHostKeyChecking=no \
      "${USER}@${IP}" \
      "exit 0" \
  && break \
  || echo "${index} of ${max_connection_attempts} ..."

  sleep 5
  (( index+=1 ))
done

# Create $IMAGEBUILDER_TEST_DIR directory and upload tests there
scp -r \
    -i "${PRIVATE_SSH_KEY}" \
    -o UserKnownHostsFile="${TEMPDIR}/known_hosts" \
    -o StrictHostKeyChecking=no \
    "${TESTS_DIR}" "${USER}@${IP}:${IMAGEBUILDER_TEST_DIR}/"

# Run tests
ssh -i "${PRIVATE_SSH_KEY}" \
    -o UserKnownHostsFile="${TEMPDIR}/known_hosts" \
    -o StrictHostKeyChecking=no \
    "${USER}@${IP}" \
    "/bin/bash -eu -c 'chmod +x ${IMAGEBUILDER_TEST_DIR}/run-tests-on-instance.sh && PACKER_SSH_USERNAME=${PACKER_SSH_USERNAME} SOLUTION_NAME=${SOLUTION_NAME} ${IMAGEBUILDER_TEST_DIR}/run-tests-on-instance.sh'" \
      && lcstatus=$? || lcstatus=$?

echo "--> Deleting the temporary instance (${INSTANCE}) ..."
gcloud -q compute instances delete "${INSTANCE}" --zone="${ZONE}"

exit ${lcstatus}
