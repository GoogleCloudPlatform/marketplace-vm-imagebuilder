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

# Include default recipe from apache2 cookbook.
include_recipe 'apache2::default'

# Create custom index.html file.
# The source file is stored in the file directory in this cookbook.
cookbook_file '/var/www/html/index.html' do
  source 'index.html'
  owner node['sample-app']['user']
  group node['sample-app']['user']
  mode '644'
  action :create
end
