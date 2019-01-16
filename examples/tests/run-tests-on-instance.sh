#!/bin/bash
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eu

# VARIABLES are come from run-tests.sh as export variables
for var in PACKER_SSH_USERNAME SOLUTION_NAME; do
  if ! [[ -v "${var}" ]]; then
    echo "${var} env variable is required"
    exit 1
  fi
done

declare -i SUCCESS_CNT=0
declare -i FAILURE_CNT=0

function success() {
  (( SUCCESS_CNT+=1 ))
  echo "> PASSED";
}

function failure() {
  (( FAILURE_CNT+=1 ))
  echo "> FAILED"
}

echo "==> Testing ${SOLUTION_NAME} ..."

# This test verify that a temporary user was deleted.
echo "--> (Test) Is ssh_username (${PACKER_SSH_USERNAME}) deleted"
grep -q "${PACKER_SSH_USERNAME}" /etc/passwd && failure || success

echo "==> Tests results: SUCCESSES=${SUCCESS_CNT} FAILURES=${FAILURE_CNT}"
exit ${FAILURE_CNT}
