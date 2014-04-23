#
# Cookbook Name:: collectd
# Library:: default
# Author:: François Ménabé
# Description:: Library for generating configuration from attributes.
#

# Tabulation value in generated files.
TAB = "    "


def get_collectd_conf(attributes)
    collectd_config = {
        'params'    => {},
        'plugins'   => {},
        'chains'    => {'plugins' => [], 'precache' => {}, 'postcache' => {}}
    }
    attributes.each do |attr, value|
        # Merge global parameters.
        merge_configs(collectd_config['params'], hashify(value)) \
            if attr.end_with?('_params')

        # Merge plugins.
        merge_configs(collectd_config['plugins'], hashify(value)) \
            if attr.end_with?('_plugins')

        # Merge postcache and precache chains.
        ['precache', 'postcache'].each do |cache_type|
            if attr.end_with?("_#{cache_type}")
                merge_configs(
                   (collectd_config['chains'][cache_type]['rules'] ||= {}),
                   hashify(value['rules'])
                ) if value.include?('rules')
                merge_configs(
                    (collectd_config['chains'][cache_type]['default'] ||= {}),
                    hashify(value['default'])
                ) if value.include?('default')

                if value.include?('plugins')
                    value['plugins'].each do |plugin|
                        collectd_config['chains']['plugins'].push(plugin) \
                            unless collectd_config['chains']['plugins'].include?(plugin)
                    end
                end
            end
        end
    end
    collectd_config
end

def hashify(config)
    case config
    # If config is a simple element (string, boolean), just return it.
    when String
        # This allow to get datas from encrypted databags.
        if config.start_with?('$DATABAG')
            bag, item, *values = config.scan(/\[[^\[\]]*\]/).map{|elt| elt[1..-2]}
            config = Chef::EncryptedDataBagItem.load(bag, item)
            values.each { |val|
                config = config[val.start_with?('$') ? node[val[1..-1]] : val]
            }
        end
        return config
    when TrueClass, FalseClass
        return config
    # If config is a hash, recursively hashify values.
    when Hash
        Hash[config.map{|key, value| [key, hashify(value)]}]
    # If config is an array, all element of the array must be of the same type.
    # This allow to check the first element for knowing in which case we are.
    # Values can be:
    #   * strings: different values of an instruction (like 'ProcessMatch' of
    #     the 'processes' plugin
    #   * array: hack for allowing ordered hash (as JSON in chef database does
    #     not keep order). Values of theses arrays are hash of one element.
    #   * hash of one elements: manage the recursion of the previous case.
    #   * hash: configurations for tag used multiple time (like 'Match' tag of
    #     'tail' plugin).
    when Array
        case config[0]
        when String
            config
        when Hash
            if config[0].length > 1
                config.map{|elt| hashify(elt)} \
            else
                Hash[config.map{|elt| elt.map{|key, value| [key, hashify(value)]}[0]}]
            end
        when Array
            config.map{|elt| hashify(elt)}
        end
    end
end


# Deep merge two hash.
def merge_configs(hash, other_hash)
    other_hash.each do |key, value|
        if !hash.include?(key) || hash[key].nil?
            hash[key] = value
            next
        end

        case value
        when String
            if !hash[key].include?(value)
                hash[key] = [hash[key]] if hash[key].kind_of?(String)
                hash[key].push(value)
            end
        when Array
            value.each do |elt|
                if !hash[key].include?(elt)
                    hash[key] = [hash[key]] if hash[key].kind_of?(String)
                    hash[key].push(elt)
                end
            end
        when Hash
            merge_configs(hash[key], value)
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
    content.concat(config['params'].map{|param, value| "#{param} #{value}"})
    content.push('')

    # Plugins which provide logging functions should be loaded first, so log
    # messages generated when loading or configuring other plugins can be
    # accessed.
    content.concat([
        "LoadPlugin syslog",
        "",
        "<Plugin \"syslog\">",
        "#{TAB}LogLevel \"info\"",
        "</Plugin>",
        "",
        ""
    ])

    # Load plugins.
    content.concat(config['plugins'].keys().map{|plugin| "LoadPlugin #{plugin}"})
    content.push('')


    config['plugins'].each do |name, conf|
        if !conf.nil?
            content.push("<Plugin \"#{name}\">")
            content.concat(gen_block(conf))
            content.push("</Plugin>")
            content.push("")
        end
    end
    content.push("")

    # Generate filters.
    content.concat(config['chains']['plugins'].map{|plugin| "LoadPlugin #{plugin}"})
    if !config['chains']['precache'].empty?
        precache_config = config['chains']['precache']
        content.push("<Chain \"PreCache\">")
        content.concat(gen_block(precache_config['rules'], level=1)) \
            if precache_config.include?('rules')
        content.concat(gen_block(precache_config['default'], level=1)) \
            if precache_config.include?('default')
        content.push("</Chain>")
    end
    if !config['chains']['postcache'].empty?
        postcache_config = config['chains']['postcache']
        content.push("<Chain \"PostCache\">")
        content.concat(gen_block(postcache_config['rules'], level=1)) \
            if postcache_config.include?('rules')
        content.concat(gen_block(postcache_config['default'], level=1)) \
            if postcache_config.include?('default')
       content.push("</Chain>")
    end
    content.push("")

    content.join("\n")
end


def gen_block(conf, level=1)
    result = []
    conf.each do |attr, value|
        if attr.start_with?('-')
            balise, name = attr[1..-1].split(':')
            if name.nil? || name.empty?
                value.each do |elt|
                    result.push("#{TAB * level}<#{balise}>")
                    result.concat(gen_block(elt, level + 1))
                    result.push("#{TAB * level}</#{balise}>")
                end
            else
                result.push("#{TAB * level}<#{balise} \"#{name}\">")
                result.concat(gen_block(value, level + 1))
                result.push("#{TAB * level}</#{balise}>")
            end
        else
            if value.kind_of?(String)
                result.push(
                    "#{TAB * level}#{attr} \"#{value.split().join('" "')}\"")
            elsif value.kind_of?(TrueClass) or value.kind_of?(FalseClass)
                result.push("#{TAB * level}#{attr} #{value}")
            elsif value.kind_of?(Array)
                result.concat(value.map{|val|
                    val.kind_of?(TrueClass) || val.kind_of?(FalseClass) \
                        ? "#{TAB * level}#{attr} #{val}" \
                        : "#{TAB * level}#{attr} \"#{val.split().join('" "')}\""
                })
            end
        end
    end
    result
end
