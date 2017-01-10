#
# Cookbook Name:: collectd
# Recipe:: default
# Author:: François Ménabé
# Description:: Deploy and configure collectd (>= 5.4).
#

# For Ubuntu < 14.04, install a custom package.
if node['platform'] == 'ubuntu'
  include_recipe "collectd::ubuntu"
end

include_recipe "collectd::config"
