#
# Cookbook Name:: collectd
# Recipe:: config
# Author:: François Ménabé
# Description:: Configure collectd.
#


# Get collectd configuration (main params, plugins, chains).
Chef::Log.info("get configuration from attributes")
files = get_collectd_conf(convert(node.to_hash))

# Remove everything in the directory except our configuration files.
ruby_block 'remove_unused_files' do
    block do
        cur_files = Dir.entries('/etc/collectd')
                       .select{ |path| path != '.' && path != '..' }
                       .map{ |path| "/etc/collectd/#{path}" }
        cur_files.each do |filepath|
            Chef::Log.info(filepath)
            if !files.include?(filepath)
                Chef::Log.info("removing '#{filepath}'")
                FileUtils.remove_entry(filepath)
            end
        end
    end
    action :run
end

# Deploy configuration file and restart service if there is any change.
service('collectd') { action :nothing }
files.each do |filepath, content|
    file filepath do
        mode '0644'
        owner 'root'
        group 'root'
        content content
        notifies :restart, "service[collectd]", :delayed
    end
end
