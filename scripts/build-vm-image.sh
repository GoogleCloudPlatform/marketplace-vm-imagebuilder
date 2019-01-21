#!/bin/bash
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

set -eu

# Ensure all required env vars are supplied.
for var in BUCKET CHEF_DIR KEY_FILE_PATH PACKER_BINARY PACKER_DIR PROJECT SOLUTION_NAME; do
  if ! [[ -v "${var}" ]]; then
    echo "${var} env variable is required"
    exit 1
  fi
done

function _register_gcloud_config() {
  local -r config_name="imagebuilder${RANDOM}"

  gcloud config configurations create "${config_name}" --no-activate

  # CLOUDSDK_ACTIVE_CONFIG_NAME env sets active gcloud configuration within this shell session.
  export CLOUDSDK_ACTIVE_CONFIG_NAME="${config_name}"

  # This trap removes the configuration after the end of program life.
  trap "unset CLOUDSDK_ACTIVE_CONFIG_NAME && gcloud config configurations delete ${config_name} -q" EXIT

  gcloud config set project "${PROJECT}"
  gcloud auth activate-service-account --key-file="${KEY_FILE_PATH}"
  gcloud info
}

# Print environment variables.
env

# Register a new gcloud configuration.
_register_gcloud_config

# Set default value for unset variables.
# :: These variables are readonly wide.
readonly RUN_TESTS="${RUN_TESTS:-false}"
readonly ATTACH_LICENSE="${ATTACH_LICENSE:-false}"
readonly IMAGE_NAME="${IMAGE_NAME:-${SOLUTION_NAME}-v$(($(date +%s%N)/1000000))}"
# :: These variables are export wide.
export ZONE="${ZONE:-us-central1-f}"
export USE_INTERNAL_IP="${USE_INTERNAL_IP:-false}"

# Set helpful variables.
# :: These variables are readonly wide.
readonly SCRIPT_DIR=$(readlink -f "$(dirname "${BASH_SOURCE[0]}")")
readonly INPUT_TEMPLATE="${PACKER_DIR}/${SOLUTION_NAME}/packer.in.json"
# :: These variables are export wide.
export FINAL_IMAGE="${IMAGE_NAME}"
export PRE_IMAGE="${FINAL_IMAGE}-pre"
export PACKER_SSH_USERNAME="packer"

echo ">>> Starting image build for ${SOLUTION_NAME}"

echo ">>> Using image name: ${IMAGE_NAME}"

# Make sure that the images (including pre and published) do not exist.
"${SCRIPT_DIR}/check-image-existence.sh" || exit 1

echo "Packer: $("${PACKER_BINARY}" -v)"

# Build the pre-image with packer.
"${PACKER_BINARY}" build -color=false \
  -var "chefdir=${CHEF_DIR}" \
  -var "keyfile=${KEY_FILE_PATH}" \
  -var "project=${PROJECT}" \
  -var "zone=${ZONE}" \
  -var "imagename=${PRE_IMAGE}" \
  -var "use_internal_ip=${USE_INTERNAL_IP}" \
  -var "log_bucket=${BUCKET}/logs" \
  -var "ssh_username=${PACKER_SSH_USERNAME}" \
  <(python "${SCRIPT_DIR}/packergen.py" "${INPUT_TEMPLATE}")

# Label an instance.
gcloud beta compute images add-labels "${PRE_IMAGE}" --labels="auto=pre"

if "${RUN_TESTS}"; then
  # Run imagebuilder tests.
  "${SCRIPT_DIR}/run-tests.sh"
fi

if "${ATTACH_LICENSE}"; then
  # Create the final image and delete the pre-image.
  LICENSE="$(jq -re '.license' "${INPUT_TEMPLATE}")" "${SCRIPT_DIR}/attach-license.sh"
else
  # FINAL_IMAGE will point to the actual final product of this script
  export FINAL_IMAGE="${PRE_IMAGE}"
fi

echo "==> Finished creating image ${FINAL_IMAGE}"

if [[ -v PUBLISH_TO_PROJECT ]]; then
  "${SCRIPT_DIR}/publish.sh"
fi

echo ">>> All done."
