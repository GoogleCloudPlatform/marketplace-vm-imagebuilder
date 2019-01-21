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
for var in FINAL_IMAGE PRE_IMAGE PROJECT; do
  if ! [[ -v "${var}" ]]; then
    echo "${var} env variable is required"
    exit 1
  fi
done

function check_existence() {
  local -r image="$1"
  local -r project="$2"
  local -r count="$(gcloud compute images list \
    --filter="name=${image}" \
    --project="${project}" \
    --format=json \
    | jq 'length')"

  if (( "${count}" > 0 )); then
    echo "ERROR: Image ${image} already exists in project ${project}"
    exit 1
  fi
}

check_existence "${FINAL_IMAGE}" "${PROJECT}"
check_existence "${PRE_IMAGE}" "${PROJECT}"

if [[ -v PUBLISH_TO_PROJECT ]]; then
  check_existence "${FINAL_IMAGE}" "${PUBLISH_TO_PROJECT}"
fi
