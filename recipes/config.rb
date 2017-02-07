#
# Cookbook Name:: collectd
# Recipe:: config
# Author:: François Ménabé
# Description:: Configure collectd.
#


# Get collectd configuration (main params, plugins, chains).
Chef::Log.info('get configuration from attributes')
pkgs, files = get_collectd_conf(convert(node.to_hash))

# Remove everything in the directory except our configuration files.
if node['collectd']['deb']['supported_platforms'].include?(node['platform'])
  ruby_block 'remove_unused_files' do
    block do
      cur_files = Dir.entries('/etc/collectd')
                     .select{ |path| path != '.' && path != '..' }
                     .map{ |path| "/etc/collectd/#{path}" }
      cur_files.each do |filepath|
        if !files.include?(filepath)
          Chef::Log.info("removing '#{filepath}'")
          FileUtils.remove_entry(filepath)
        end
      end
    end
    action :run
  end
end

# Install dependencies, deploy configuration file and restart
# service if there is any change.
service('collectd') { action :nothing }

pkgs.each do |pkg|
  package pkg do
    action :install
    notifies :restart, 'service[collectd]', :delayed
  end
end

files.each do |filepath, content|
  file filepath do
    mode '0644'
    owner 'root'
    group 'root'
    content content
    notifies :restart, 'service[collectd]', :delayed
  end
end
