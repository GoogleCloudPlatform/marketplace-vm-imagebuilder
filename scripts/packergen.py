#!/usr/bin/env python3
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

import argparse
import json
import sys

# Install chef-solo via deb package.
INSTALL_CHEF_SOLO = r"""
declare -r VERSION=18.5.0
declare -r SHA256=1918e72eebeea0dd2f7680b08f1362d699b37570431ebca3c1b4fbe40cfc2abb

curl "https://packages.chef.io/files/stable/chef/${VERSION}/debian/11/chef_${VERSION}-1_amd64.deb" -o chef-solo.deb \
  && echo "${SHA256} chef-solo.deb" | sha256sum -c \
  && sudo dpkg --install chef-solo.deb
"""

# GCE VM shutdown-script to clean up the image.
SHUTDOWN_SCRIPT = r"""#!/bin/bash -eu
readonly BUCKET="$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/shutdown-script-log-bucket)"
readonly LOGNAME="$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/attributes/shutdown-script-log-name)"

# Execute inlined script and redirect output to a GCS file.
/bin/bash -eu <(cat << 'EOF'

echo "--> Cleaning /etc/ssh/ssh_host_* ..."
for ssh_host in /etc/ssh/ssh_host_*; do
  cat /dev/null > $ssh_host && echo "  > $ssh_host: DONE"
done

echo "--> Checking for existence of Root authorized_keys..."
if [[ -f /root/.ssh/authorized_keys ]]; then
  echo "  > Removing Root authorized_keys..."
  rm /root/.ssh/authorized_keys
fi

echo "--> Cleaning home directories..."
for user in $(cat /var/lib/google/google_users | grep -v "root"); do
  pkill -u $user || echo "  > $user: NO PROCESS TO KILL..."
  while pgrep -u $user > /dev/null;
  do
    sleep 1;
    echo "> Waiting for $user processes to terminate...";
  done
  userdel -r $user && echo "  > $user: REMOVED"
done

echo "--> Removing google_users file..."
rm /var/lib/google/google_users

echo "--> Cleaning all log files..."
find /var/log/ -type f -delete

echo "SHUTDOWN SCRIPT COMPLETED"
EOF
) 2>&1 | gsutil -h "Content-Type:text/plain" cp - "gs://$BUCKET/$LOGNAME"

# Cleaning /root/ ...
# Clean all files except:
#  - .profile
#  - .bashrc
find /root/ -mindepth 1 ! -name .profile ! -name .bashrc -delete
"""

STOP_SERVICES_SCRIPT = r"""
echo "--> Stopping syslog service..."
# Syslog is restarted on failure by default. Needed actions:
#  - disable
#  - stop
#  - enable (syslog is still stopped till next restart)
systemctl disable rsyslog.service
systemctl stop rsyslog.service
systemctl enable rsyslog.service

echo "--> Stopping Google services..."
# We need to stop google services to avoid accidental creation of
# users by the account daemon
# Reference to google-guest-agent
# https://github.com/GoogleCloudPlatform/compute-image-packages/tree/master/packages/python-google-compute-engine
systemctl stop google-guest-agent.service
"""

VERIFY_SHUTDOWN_SCRIPT = r"""
# Download and display log via streaming transfers
gsutil cp gs://{{ user `log_bucket` }}/{{ user `shutdown_log_name` }} -
# Verify shutdown script
gsutil cat gs://{{ user `log_bucket` }}/{{ user `shutdown_log_name` }} \
  | egrep -q '^SHUTDOWN SCRIPT COMPLETED$'
echo "--> Shutdown script execution verified!"
echo "--> Deleting log file..."
gsutil rm gs://{{ user `log_bucket` }}/{{ user `shutdown_log_name` }}
"""

PACKER_OVERRIDABLE_CONFIG = [
  "disk_size"
  "image_family",
  "machine_type",
  "source_image_family",
  "source_image_project_id",
]


def _inline_format(command):
  return command.strip().split('\n')


def _sudo_shell(command):
  return {
      'type': 'shell',
      'execute_command': (
          'chmod +x {{ .Path }}; '
          'sudo /bin/bash -eu -c \'{{ .Vars }} {{ .Path }}\''
      ),
      'inline_shebang': '/bin/bash -eu',
      'inline': _inline_format(command)
  }


def _purge_chef():
  return _sudo_shell('apt-get purge -y --auto-remove chef')


def _verify_shutdown_script():
  """Post-processor to verify that shutdown script has executed."""
  return {
      'type': 'shell-local',
      'inline': _inline_format(VERIFY_SHUTDOWN_SCRIPT),
  }


def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('input', help='Input JSON')
  args = parser.parse_args()

  with open(args.input, 'r') as f:
    data = json.load(f)

  builder = {
      'type': 'googlecompute',
      'machine_type': 'e2-standard-2',
      'account_file': '{{ user `keyfile` }}',
      'service_account_email': '{{ user `service_account_email` }}',
      'project_id': '{{ user `project` }}',
      'zone': '{{ user `zone` }}',
      'ssh_username': '{{ user `ssh_username` }}',
      'image_name': '{{ user `imagename` }}',
      'use_internal_ip': '{{ user `use_internal_ip` }}',
      'instance_name': 'imagebuilder-{{uuid}}',
      'metadata': {
          'block-project-ssh-keys': 'true',
          'shutdown-script': SHUTDOWN_SCRIPT,
          'shutdown-script-log-name': '{{ user `shutdown_log_name` }}',
          'shutdown-script-log-bucket': '{{ user `log_bucket` }}',
      },
      'tags': ['imagebuilder-workers']
  }

  # Overrides the allowed attributes
  builder.update(
    {key: data.get(key) for key in PACKER_OVERRIDABLE_CONFIG if key in data}
  )

  content = {
      'variables': {
          'chefdir': None,
          'project': None,
          'zone': None,
          'imagename': None,
          'use_internal_ip': 'true',
          'shutdown_log_name': 'shutdown-log-{{ uuid }}.txt',
          'log_bucket': None,
          'ssh_username': None,
      },
      'builders': [builder],
      'provisioners': [
          {
              'type': 'chef-solo',
              'install_command': INSTALL_CHEF_SOLO,
              'cookbook_paths': ['{{ user `chefdir` }}/cookbooks/'],
              'run_list': data['chef']['run_list'],
              'chef_license': 'accept'
          },
          _purge_chef(),
          _sudo_shell(STOP_SERVICES_SCRIPT),
          _sudo_shell('apt-get clean')
      ],
      'post-processors': [
          _verify_shutdown_script()
      ],
  }
  print(json.dumps(content, sort_keys=True, indent=2))

  return 0


if __name__ == '__main__':
  sys.exit(main())
