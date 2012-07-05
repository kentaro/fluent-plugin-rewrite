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

        element.keys.each do |k|
          # read and throw away to supress unread configuration warning
          element[k]
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
      if @remove_prefix and
        ((tag.start_with?(@removed_prefix_string) && tag.length > @removed_length) || tag == @remove_prefix)
        tag = tag[@removed_length..-1] || ''
      end

      if @add_prefix
        tag = tag && tag.length > 0 ? @added_prefix_string + tag : @add_prefix
      end

      es.each do |time, record|
        filtered_tag, record = rewrite(tag, record)
        Engine.emit(filtered_tag, time, record) if filtered_tag && record
      end

      chain.next
    end

    def rewrite(tag, record)
      rules.each do |rule|
        tag, record, last = apply_rule(rule, tag, record)

        break  if last
        return if !tag && !record
      end

      [tag, record]
    end

    def apply_rule(rule, tag, record)
      tag_prefix = tag && tag.length > 0 ? "." : ""
      key        = rule["key"]
      pattern    = rule["pattern"]
      last       = nil

      return [tag, record] if !key || !record.has_key?(key)

      if duplicate_key = rule["duplicate"]
        duplicate_key = duplicate_key.gsub(/__TAG__/, tag)
        record[duplicate_key] = record[key]
      end

      return [tag, record] unless pattern

      if matched = record[key].match(rule["regex"])
        return if rule["ignore"]

        if rule["replace"]
          replace = rule["replace"]
          record[key] = record[key].gsub(rule["regex"], replace)
        end

        if rule["append_to_tag"]
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
        if rule["append_to_tag"] && rule["fallback"]
          tag += (tag_prefix + rule["fallback"])
        end
      end

      [tag, record, last]
    end
  end
end
