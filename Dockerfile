# Copyright 2024 Google LLC. All rights reserved.
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

FROM marketplace.gcr.io/google/debian12

ENV PACKER_VERSION=1.11.2
ENV PACKER_SHA256=ced13efc257d0255932d14b8ae8f38863265133739a007c430cae106afcfc45a
ENV PACKER_BINARY=/bin/packer

ENV CHEF_DIR=/chef
ENV PACKER_DIR=/packer/templates
ENV TESTS_DIR=/tests
ENV KEY_FILE_PATH=/service-account.json

# Installs packages
RUN set -eux \
    && apt-get update \
    && apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        jq \
        openssh-client \
        python3 \
        unzip

# Install gcloud (https://cloud.google.com/sdk/docs/install#deb)
RUN apt-get update \
    && apt-get -y install apt-transport-https ca-certificates gnupg curl \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get -y install google-cloud-cli

# Installs Packer
RUN set -eux \
    # Downloads binary
    && curl -O "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip" \
    # Verifies checksum
    && echo "${PACKER_SHA256} packer_${PACKER_VERSION}_linux_amd64.zip" | sha256sum -c \
    # Unzips binary
    && unzip "packer_${PACKER_VERSION}_linux_amd64.zip" \
    && rm "packer_${PACKER_VERSION}_linux_amd64.zip" \
    # Moves binary
    && mv packer ${PACKER_BINARY} \
    && chmod +x ${PACKER_BINARY} \
    # Downloads source code
    && curl -L -o packer.tar.gz "https://github.com/hashicorp/packer/archive/v${PACKER_VERSION}.tar.gz" \
    && mkdir -p /usr/local/src/packer \
    && tar -xzf packer.tar.gz -C /usr/local/src/packer --strip-components=1 \
    && rm packer.tar.gz

# Downloads licenses
RUN set -eux \
    && mkdir -p /usr/share/imagebuilder \
    && curl -o /usr/share/imagebuilder/packer.LICENSE "https://raw.githubusercontent.com/hashicorp/packer/v${PACKER_VERSION}/LICENSE" \
    && curl -o /usr/share/imagebuilder/chef-solo.LICENSE "https://raw.githubusercontent.com/chef/chef/master/LICENSE"

COPY scripts /imagebuilder

ENTRYPOINT ["/imagebuilder/build-vm-image.sh"]
