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
for var in PROJECT FINAL_IMAGE PUBLISH_TO_PROJECT; do
  if ! [[ -v "${var}" ]]; then
    echo "${var} env variable is required"
    exit 1
  fi
done

echo "==> Publishing image ${FINAL_IMAGE} to ${PUBLISH_TO_PROJECT}"

gcloud compute images create "${FINAL_IMAGE}" \
  --source-image="${FINAL_IMAGE}" \
  --source-image-project="${PROJECT}" \
  --project="${PUBLISH_TO_PROJECT}"

echo "==> Image ${FINAL_IMAGE} published to ${PUBLISH_TO_PROJECT}!"
