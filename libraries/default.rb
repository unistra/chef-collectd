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
        merge_configs(collectd_config['params'], list2hash(value)) \
            if attr.end_with?('_params')

        # Merge plugins.
        merge_configs(collectd_config['plugins'], list2hash(value)) \
            if attr.end_with?('_plugins')

        # Merge postcache and precache chains.
        ['precache', 'postcache'].each do |cache_type|
            if attr.end_with?("_#{cache_type}")
                merge_configs(
                   (collectd_config['chains'][cache_type]['rules'] ||= {}),
                   list2hash(value['rules'])
                ) if value.include?('rules')
                merge_configs(
                    (collectd_config['chains'][cache_type]['default'] ||= {}),
                    list2hash(value['default'])
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


def merge_configs(hash, other_hash)
    other_hash.each do |key, value|
        if !hash.include?(key) || hash[key].nil?
            hash[key] = value
        elsif value.kind_of?(String)
            hash[key] = [hash[key]] if hash[key].kind_of?(String)
            hash[key].push(value) if !hash[key].include?(value)
        elsif value.kind_of?(Array)
            hash[key] = [hash[key]] if hash[key].kind_of?(String)
            value.each{ |val|
                hash[key].push(val) unless hash[key].include?(val)
            }
        elsif value.kind_of?(Hash)
            merge_configs(hash[key], value)
        end
    end
end


def list2hash(config)
    hash = {}
    config.each do |elt|
        if elt.kind_of?(Hash)
            elt.each do |key, value|
                hash[key] = value.kind_of?(Array) ? list2hash(value) : value
            end
        else
            return config.map{|elt| elt.kind_of?(Array) ? list2hash(elt) : elt}
        end
    end
    hash
end


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

    # Generate plugins configurations
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
