#
# Copyright:: Copyright (c) 2017 GitLab Inc.
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
# limitations under the License.
#

account_helper = AccountHelper.new(node)
consul_helper = ConsulHelper.new(node)

account "Consul user and group" do
  username account_helper.consul_user
  uid node['consul']['uid']
  ugid account_helper.consul_user
  groupname account_helper.consul_user
  gid node['consul']['gid']
  home node['consul']['dir']
  manage node['gitlab']['manage-accounts']['enable']
end

directory node['consul']['dir'] do
  owner account_helper.consul_user
end

%w(
  config_dir
  data_dir
  log_directory
  script_directory
).each do |dir|
  directory node['consul'][dir] do
    owner account_helper.consul_user
  end
end

# By default consul only listens on the loopback interface.
# If we're running in server mode then this is not useful
if node['consul']['configuration']['server']
  node.default['consul']['configuration']['client_addr'] = node['ipaddress'] unless node['consul']['configuration'].attribute?('client_addr')
end

file "#{node['consul']['dir']}/config.json" do
  content consul_helper.configuration
  owner account_helper.consul_user
  notifies :restart, "service[consul]"
end

node['consul']['services'].each do |service|
  include_recipe "consul::service_#{service}"
end

include_recipe 'consul::watchers'

include_recipe 'consul::enable_daemon'
