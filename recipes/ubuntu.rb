#
# Cookbook Name:: collectd
# Recipe:: ubuntu
# Author:: François Ménabé
# Description:: Install collectd on Ubuntu.
#

# For Ubuntu < 14.04, install a custom package.
if ['10.04', '12.04'].include? node['platform_version']
    dependencies = []
    deb_files = []

    # Get dependencies and deb files according to the Ubuntu version.
    if node['platform_version'] == '10.04'
        dependencies = ['defoma', 'fontconfig', 'fontconfig-config', 'libcairo2',
            'libdatrie1', 'libdirectfb-1.2-0', 'libfontconfig1', 'libfontenc1',
            'libpango1.0-0', 'libpango1.0-common', 'libpixman-1-0', 'librrd4',
            'libsysfs2', 'libthai-data', 'libthai0', 'libts-0.0-0',
            'libxcb-render-util0', 'libxcb-render0', 'libxfont1', 'libxft2',
            'libxrender1', 'tsconf', 'ttf-dejavu', 'ttf-dejavu-core',
            'ttf-dejavu-extra', 'x-ttcidfont-conf', 'xfonts-encodings',
            'xfonts-utils']
        deb_files = [
            'collectd-core_5.4.0-lucid1_amd64.deb',
            'collectd_5.4.0-lucid1_amd64.deb'
        ]
    elsif node['platform_version'] == '12.04'
        dependencies = ['libdbi1', 'librrd4', 'libltdl7', 'liblvm2-dev']
        deb_files = [
            'collectd-core_5.4.0-precise1_amd64.deb',
            'collectd_5.4.0-precise1_amd64.deb'
        ]
    end

    # Install dependencies.
    dependencies.each { |dep| package(dep) { action :install } }

    # Install custom package.
    deb_files.each do |deb|
        cookbook_file("/tmp/#{deb}") { source deb }
        dpkg_package(deb) do
            source "/tmp/#{deb}"
            action :install
        end
    end
elsif ['14.04'].include? node['platform_version']
    package('collectd') { action :install }
else
    Chef::Log.error("Unsupported Ubuntu version!")
end
