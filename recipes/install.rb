# https://github.com/collectd/collectd-ci

case node['platform']
when *node['collectd']['deb']['supported_platforms']
  case node['lsb']['codename']
  # Manage old Ubuntu Lucid ...
  when 'lucid'
    node['collectd']['lucid']['dependencies'].each { |pkg| package(pkg) { action :install } }
    node['collectd']['lucid']['pkgs'].each do |pkg|
        cookbook_file("/tmp/#{pkg}") { source pkg }
        dpkg_package(pkg) do
            source "/tmp/#{pkg}"
            action :install
        end
    end
  # Manage Debian/Ubuntu LTS versions.
  when *node['collectd']['deb']['supported_versions']
    apt_repository 'collectd-ci' do
        uri           node['collectd']['apt_url']
        distribution  node['lsb']['codename']
        components    ["collectd-#{node['collectd']['version']}"]
        key           node['collectd']['key']
    end
    package('collectd') { action :install }
  else
    log "unsupported platform version #{node['platform']}/#{node['lsb']['codename']}"
    raise "unsupported platform version #{node['platform']}/#{node['lsb']['codename']}"
  end
when *node['collectd']['rpm']['supported_platforms']
  case node['platform_version'][0]
  # Manage Redhat/Centos supported versions.
  when *node['collectd']['rpm']['supported_versions']
    yum_repository 'collectd-ci' do
        description 'Collectd CI'
        baseurl     node['collectd']['yum_url'] % {version: node['platform_version'][0]}
        gpgkey      node['collectd']['key']
        # (16/01/2017) Centos5 packages are not signed ...
        gpgcheck    false
        action      :create
    end
    package('collectd') { action :install }
  else
    log "unsupported platform version #{node['platform']}/#{node['platform_version']}"
    raise "unsupported platform version #{node['platform']}/#{node['platform_version']}"
  end
else
    log "unsupported platform '#{node['platform']}'"
    raise "unsupported platform '#{node['platform']}'"
end

service('collectd') { action :enable }
