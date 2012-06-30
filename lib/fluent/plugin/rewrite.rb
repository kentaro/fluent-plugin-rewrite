module Fluent
  class RewriteOutput < Output
    Fluent::Plugin.register_output('rewrite', self)

    config_param :remove_prefix, :string, :default => nil
    config_param :add_prefix,    :string, :default => nil

    attr_reader  :rules

    def configure(conf)
      super

      if @remove_prefix
        @removed_prefix_string = @remove_prefix + '.'
        @removed_length = @removed_prefix_string.length
      end
      if @add_prefix
        @added_prefix_string = @add_prefix + '.'
      end

      @rules = conf.elements.select { |element|
        element.name == 'rule'
      }.each { |element|
        if element.has_key?("pattern")
          element["regex"] = Regexp.new(element["pattern"])
        end
      }
    end

    def start
      super
    end

    def shutdown
      super
    end

    def emit(tag, es, chain)
      es.each do |time, record|
        tag, record = rewrite(tag, record)
        Engine.emit(tag, time, record) if tag && record
      end

      chain.next
    end

    def length_will_be_removed
      return 0 unless @remove_prefix
      (@remove_prefix + '.').length
    end

    def rewrite(tag, record)
      if @remove_prefix and
          ((tag.start_with?(@removed_prefix_string) && tag.length > @removed_length) ||
          tag == @remove_prefix)
        tag = tag[@removed_length..-1]
      end

      if @add_prefix
        tag = tag && tag.length > 0 ? @added_prefix_string + tag : @add_prefix
      end

      rules.each do |rule|
        tag, record = apply_rule(rule, tag, record)
        return if !tag && !record
      end

      [tag, record]
    end

    def apply_rule(rule, tag, record)
      tag     = rule["append_to_tag"] ? tag.dup : tag
      key     = rule["key"]
      pattern = rule["pattern"]

      return [tag, record] if !key || !record.has_key?(key)
      return [tag, record] unless pattern

      if matched = record[key].match(rule["regex"])
        return if rule["ignore"]

        if rule["replace"]
          replace = rule["replace"].to_s
          record[key] = record[key].gsub(rule["regex"], replace)
        end

        if rule["append_to_tag"]
          matched.captures.each { |m| tag << ".#{m}" }
        end
      else
        if rule["append_to_tag"] && rule["fallback"]
          tag << ".#{rule["fallback"]}"
        end
      end

      [tag, record]
    end
  end
end
