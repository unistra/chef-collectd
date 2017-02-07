default['collectd_params'] = [
    {'FQDNLookup' => false}
]

# See https://github.com/collectd/collectd-ci for valid versions.
default['collectd']['version'] = '5.7'
default['collectd']['key'] = 'http://pkg.ci.collectd.org/pubkey.asc'
default['collectd']['apt_url'] = 'http://pkg.ci.collectd.org/deb/'
default['collectd']['yum_url'] =
    "http://pkg.ci.collectd.org/rpm/collectd-#{node['collectd']['version']}/epel-%{version}-$basearch"

default['collectd']['rpm']['supported_platforms'] = %w(centos redhat)
default['collectd']['rpm']['supported_versions'] = %w(5 6 7)
default['collectd']['rpm']['conf_file'] = '/etc/collectd.conf'
default['collectd']['rpm']['types'] = '/usr/share/collectd/types.db'
default['collectd']['rpm']['custom_types'] = '/etc/collectd-types.db.custom'

default['collectd']['deb']['supported_platforms'] = %w(debian ubuntu)
default['collectd']['deb']['supported_versions'] = %w(precise trusty xenial wheezy jessie)
default['collectd']['deb']['conf_file'] = '/etc/collectd/collectd.conf'
default['collectd']['deb']['types'] = '/usr/share/collectd/types.db'
default['collectd']['deb']['custom_types'] = '/etc/collectd/types.db.custom'


default['collectd']['lucid']['dependencies'] = %w(
  defoma fontconfig fontconfig-config libcairo2 libdatrie1 libdirectfb-1.2-0
  libfontconfig1 libfontenc1 libpango1.0-0 libpango1.0-common libpixman-1-0 librrd4
  libsysfs2 libthai-data libthai0 libts-0.0-0 libxcb-render-util0 libxcb-render0
  libxfont1 libxft2 libxrender1 tsconf ttf-dejavu ttf-dejavu-core ttf-dejavu-extra
  x-ttcidfont-conf xfonts-encodings xfonts-utils)
default['collectd']['lucid']['pkgs'] = %w(
  collectd-core_5.4.0-lucid1_amd64.deb collectd_5.4.0-lucid1_amd64.deb)
