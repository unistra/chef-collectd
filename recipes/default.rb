#
# Cookbook Name:: collectd
# Recipe:: default
# Author:: François Ménabé
# Description:: Deploy and configure collectd (>= 5.4).
#

if node['platform'] == 'ubuntu'
    include_recipe "collectd::ubuntu"
end
