#
# Cookbook Name:: collectd
# Library:: default
# Author:: François Ménabé
# Description:: Library for generating configuration from attributes.
#

require 'pp'
require 'chef/mixin/deep_merge'

# Tabulation value in generated files.
TAB = "    "

SYSLOG_CONF = %Q{
LoadPlugin syslog
<Plugin "syslog">
#{TAB}LogLevel "info"
</Plugin>

}

CONF_DIR = "/etc/collectd"
CONF_FILE = "#{CONF_DIR}/collectd.conf"
TYPES = {'ubuntu' => '/usr/share/collectd/types.db'}
CUSTOM_TYPES = "#{CONF_DIR}/types.db.custom"

# Recursively convert ImmutableArray to Array (so we can merge later).
def convert(node)
    attributes = {}
    node.each do |attr, value|
        case value
        when Hash
            attributes[attr] = convert(value)
        when Chef::Node::ImmutableArray
            attributes[attr] = value.dup
        else
            attributes[attr] = value
        end
    end
    attributes
end

# Merge configuration from roles and node.
def get_collectd_conf(attributes)
    config = {'params'      => attributes.delete('collectd_params') || {},
              'loadparams'  => attributes.delete('collectd_loadparams') || {},
              'plugins'     => hashify(attributes.delete('collectd_plugins') || {}),
              'precache'    => hashify(attributes.delete('collectd_precache') || {}),
              'postcache'   => hashify(attributes.delete('collectd_postcache') || {})}
    types = attributes.delete('collectd_types') || {}

    attributes.each do |attr, value|
        case
        when attr.start_with?('collectd_params')
            config['params'] = Chef::Mixin::DeepMerge.deep_merge!(value, config['params'])
        when attr.start_with?('collectd_loadparams')
            config['loadparams'] = Chef::Mixin::DeepMerge.deep_merge!(value, config['loadparams'])
        when attr.start_with?('collectd_plugins')
            config['plugins'] = Chef::Mixin::DeepMerge.deep_merge(hashify(value),
                                                                  config['plugins'])
        when attr.start_with?('collectd_precache')
            config['precache'] = Chef::Mixin::DeepMerge.deep_merge(hashify(value),
                                                                   config['precache'])
        when attr.start_with?('collectd_postcache')
            config['postcache'] = Chef::Mixin::DeepMerge.deep_merge(hashify(value),
                                                                    config['postcache'])
        when attr.start_with?('collectd_types')
            types = Chef::Mixin::DeepMerge.deep_merge(value, types)
        end
    end

    # Hack because lucid package has not be compiled with lvm library.
    if node['platform'] == 'ubuntu' && node['platform_version'] == '10.04'
        config['plugins'].delete('lvm')
    end

    if !types.empty?
        config['params'].update({'TypesDB' => [TYPES[node['platform']],
                                               '/etc/collectd/types.db.custom']})
        files = {CONF_FILE => gen_conf(config), CUSTOM_TYPES => gen_types(types)}
    else
        files = {CONF_FILE => gen_conf(config)}
    end

    files
end

def hashify(config)
    case config
    # If config is a simple element (string, boolean), just return it.
    when String, Integer
        # This allow to get datas from encrypted databags.
        if config.start_with?('$DATABAG')
            bag, item, *values = config.scan(/\[[^\[\]]*\]/).map{|elt| elt[1..-2]}
            config = Chef::EncryptedDataBagItem.load(bag, item)
            values.each { |val| config = config[val.start_with?('$') ? node[val[1..-1]] : val] }
        end
        config
    when TrueClass, FalseClass
        config
    # If config is a hash, recursively hashify values.
    when Hash || Mash
        Hash[config.map{|key, value| [key, hashify(value)]}]
    when Array
        case config[0]
        when Hash
             # Recursively hashify.
             Hash[config.map{ |key, value| [key, hashify(value)] }]
        when Array
            # An array of tuples is a hash so we transform the array to a
            # hash and recursively hashify values.
            if config[0].length == 2
                # Hack for managing the case when the key is present multiple times!
                hash = Hash.new
                config.each do |key, value|
                    value = hashify(value)
                    if hash[key].nil?
                        hash[key] = value
                    else
                        case hash[key]
                        when Array
                            hash[key].concat(value)
                        when Hash
                            hash[key].merge!(value)
                            # Hack for keeping order of elements!
                            val = hash[key]
                            hash.delete(key)
                            hash[key] = val
                        end
                    end
                end
                hash
            else
                config.map{ |elt| hashify(elt) }
            end
        else
            config
        end
    end
end

# Generate configuration. As the 'syslog' plugin is necessary for logging the
# collectd daemon itself, it is automatically include in the configuration in
# the main file. This main file also contain:
#   * the global parameters
#   * 'LoadPlugin' instructions,
#   * files inclusions.
# Each plugin having a configuration has its own configuration file and there
# also a file for chains.
def gen_conf(config)
    content = []

    # Generate global parameters.
    content.concat(gen_block(config['params'], level=0))

    # Plugins which provide logging functions should be loaded first, so log
    # messages generated when loading or configuring other plugins can be
    # accessed.
    content.push(SYSLOG_CONF)

    # Load plugins.
    loadplugin = Hash[config['plugins'].keys().map{ |plugin| [plugin, nil] }]
    loadplugin.merge!(config['loadparams'])
    loadplugin.sort.each do |plugin, conf|
        if conf.nil?
            content.push("LoadPlugin \"#{plugin}\"")
        else
            content.push("<LoadPlugin \"#{plugin}\">")
            content.concat(conf.map{ |param, value| "#{TAB} #{param} #{value}" })
            content.push("</LoadPlugin>")
        end
    end
    content.push('')

    # Configure plugins.
    config['plugins'].sort.each do |name, conf|
        next if conf.nil?

        content.push("<Plugin \"#{name}\">")
        content.concat(gen_block(conf))
        content.push("</Plugin>")
        content.push("")
    end
    content.push("")

    # Generate filters.
    chains_loadplugin = (config['precache'].fetch('plugins', [])
                         .concat(config['postcache'].fetch('plugins', []))
                         .uniq)
    content.concat(chains_loadplugin.map{|plugin| "LoadPlugin #{plugin}"})
    content.push("")

    if !config['precache'].empty?
        content.push("<Chain \"PreCache\">")
        content.concat(gen_block(config['precache']['rules'], level=1)) \
            if config['precache'].include?('rules')
        content.concat(gen_block(config['precache']['default'], level=1)) \
            if config['precache'].include?('default')
        content.push("</Chain>")
        content.push("")
    end

   if !config['postcache'].empty?
        content.push("<Chain \"PostCache\">")
        content.concat(gen_block(config['postcache']['rules'], level=1)) \
            if config['postcache'].include?('rules')
        content.concat(gen_block(config['postcache']['default'], level=1)) \
            if config['postcache'].include?('default')
        content.push("</Chain>")
        content.push("")
    end

    content.join("\n")
end

def gen_block(conf, level=1)
    def format_line(level, attr, value)
        if value.kind_of?(String) && !value.start_with?('"') && !value.end_with?('"')
            value = "\"#{value.split().join('" "')}\""
        end
        "#{TAB * level}#{attr} #{value}"
    end

    result = []
    conf.each do |attr, value|
        if attr.start_with?('-')
            balise, name = attr[1..-1].split(':')
            if name.nil? || name.empty?
                start_tag = "#{TAB * level}<#{balise}>"
            else
                start_tag = "#{TAB * level}<#{balise} \"#{name}\">"
            end
            end_tag = "#{TAB * level}</#{balise}>"

            if value.kind_of?(Array)
                value.each do |val|
                    result.push(start_tag)
                    result.concat(gen_block(val, level + 1))
                    result.push(end_tag)
                end
            else
                result.push(start_tag)
                result.concat(gen_block(value, level + 1))
                result.push(end_tag)
            end
        elsif value.kind_of?(Array)
            value.map do |val|
                case val
                when Hash || Mash
                    result.concat(gen_block(val, level + 1))
                else
                    result.push(format_line(level, attr, val))
                end
            end
        else
            result.push(format_line(level, attr, value))
        end
    end
    result
end

def gen_types(types)
    types.map{ |type, value| "#{type} #{value.kind_of?(Array) ? value.join(', ') : value}" }
         .join("\n")
end
