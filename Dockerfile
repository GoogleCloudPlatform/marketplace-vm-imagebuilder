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

FROM gcr.io/google-appengine/debian9:latest

ENV PACKER_VERSION 1.0.0
ENV PACKER_SHA256 ed697ace39f8bb7bf6ccd78e21b2075f53c0f23cdfb5276c380a053a7b906853
ENV PACKER_BINARY /bin/packer

ENV CHEF_DIR /chef
ENV PACKER_DIR /packer/templates
ENV TESTS_DIR /tests
ENV KEY_FILE_PATH /service-account.json

# Installs packages
RUN set -eux \
    && apt-get update \
    && apt-get install -y \
        curl \
        gnupg2 \
        jq \
        openssh-client \
        python \
        unzip

# Installs gcloud
RUN set -eux \
    && export CLOUD_SDK_REPO="cloud-sdk-stretch" \
    && echo "deb http://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - \
    && apt-get update -y && apt-get install google-cloud-sdk -y

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
