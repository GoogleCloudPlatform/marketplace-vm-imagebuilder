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
for var in PRE_IMAGE FINAL_IMAGE ZONE LICENSE LICENSE_PROJECT_NAME; do
  if ! [[ -v "${var}" ]]; then
    echo "${var} env variable is required"
    exit 1
  fi
done

echo "==> Creating a new image with license attached"

readonly DISK_NAME="${PRE_IMAGE}-disk"
echo "--> Creating disk with the pre-image..."
gcloud beta compute disks create "${DISK_NAME}" \
  --image="${PRE_IMAGE}" \
  --zone="${ZONE}" \
  --labels="auto=pre"

echo "--> Creating the image with license..."
gcloud beta compute images create "${FINAL_IMAGE}" \
  --source-disk="${DISK_NAME}" \
  --source-disk-zone="${ZONE}" \
  --licenses="https://www.googleapis.com/compute/v1/projects/${LICENSE_PROJECT_NAME}/global/licenses/${LICENSE}" \
  --labels="auto=final"

echo "--> Deleting disk and pre-image..."
gcloud -q compute disks delete "${DISK_NAME}" --zone="${ZONE}"
gcloud -q compute images delete "${PRE_IMAGE}"
