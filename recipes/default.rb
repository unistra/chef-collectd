#
# Cookbook Name:: collectd
# Recipe:: default
# Author:: François Ménabé
# Description:: Deploy and configure collectd (>= 5.4).
#

include_recipe "collectd::install"
include_recipe "collectd::config"
