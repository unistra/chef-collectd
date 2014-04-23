#
# Cookbook Name:: collectd
# Recipe:: config
# Author:: François Ménabé
# Description:: Configure collectd.
#

# Get collectd configuration (main params, plugins, chains).
collectd_conf = get_collectd_conf(node.to_hash)

# Hack because lucid package as not be compiled with lvm library.
if node['platform'] == 'ubuntu' && node['platform_version'] == '10.04'
    collectd_conf['plugins'].delete('lvm')
end

# Remove everything in the directory except the configuration file.
execute('find /etc/collectd/* -type d -not -name collectd.conf | xargs rm -rf')
execute('find /etc/collectd/* -type f -not -name collectd.conf | xargs rm -rf')

# Deploy configuration file and restart service if there is any change.
service('collectd') { action :nothing }
file '/etc/collectd/collectd.conf' do
    mode '0644'
    owner 'root'
    group 'root'
    content gen_conf(collectd_conf)
    notifies :restart, "service[collectd]", :immediately
end
