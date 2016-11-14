module Fluent
  class RewriteRule
    attr_reader :rules

    def initialize(plugin, conf)
      @plugin = plugin
      @rules = conf.elements.select {|element| element.name == 'rule' }.map do |element|
        rule = {}
        element.keys.each do |key|
          # read and throw away to supress unread configuration warning
          rule[key] = element[key]
        end
        rule["regex"] = Regexp.new(element["pattern"]) if element.has_key?("pattern")
        rule
      end
    end

    def rewrite(tag=nil, record)
      @rules.each do |rule|
        tag, record, last = apply_rule(rule, tag, record)

        break  if last
        if @plugin.is_a?(Fluent::Plugin::Output)
          return if !tag && !record
        else
          return if !record
        end
      end

      return [record] if not @plugin.is_a?(Fluent::Plugin::Output)
      return [tag, record] if @plugin.is_a?(Fluent::Plugin::Output)
    end

    def apply_rule(rule, tag=nil, record)
      tag_prefix = tag && tag.length > 0 ? "." : ""
      key        = rule["key"]
      pattern    = rule["pattern"]
      last       = nil

      return [tag, record] if !key || !record.has_key?(key)
      return [tag, record] unless pattern

      if matched = record[key].match(rule["regex"])
        return if rule["ignore"]

        if rule["replace"]
          replace = rule["replace"]
          record[key] = record[key].gsub(rule["regex"], replace)
        end

        if rule["append_to_tag"] && @plugin.is_a?(Fluent::Plugin::Output)
          if rule["tag"]
            tag += (tag_prefix + rule["tag"])
          else
            matched.captures.each do |m|
              tag += (tag_prefix + "#{m}")
            end
          end
        end

        if rule["last"]
          last = true
        end
      else
        if rule["append_to_tag"] && rule["fallback"] && @plugin.is_a?(Fluent::Plugin::Output)
          tag += (tag_prefix + rule["fallback"])
        end
      end

      return [tag, record, last]
    end
  end
end
