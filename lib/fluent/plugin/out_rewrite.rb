module Fluent
  class RewriteOutput < Output
    Fluent::Plugin.register_output('rewrite', self)

    config_param :remove_prefix, :string, :default => nil
    config_param :add_prefix,    :string, :default => nil

    attr_reader   :rules
    attr_accessor :warn_msg

    def configure(conf)
      super

      if @remove_prefix
        @removed_prefix_string = @remove_prefix + '.'
        @removed_length = @removed_prefix_string.length
      end
      if @add_prefix
        @added_prefix_string = @add_prefix + '.'
      end

      invalid_keys = Array.new

      @rules = conf.elements.select { |element|
        element.name == 'rule'
      }.each { |element|

        if element["tag"] || element["fallback"]
          element["append_to_tag"] = true
        end

        if element.has_key?("pattern") && element.has_key?("key")
          element["regex"] = Regexp.new(element["pattern"])
        else
          raise ConfigError, "out_rewrite: In the rules section, both 'key' and 'pattern' must be set."
        end

        if !@remove_prefix && !@add_prefix
          unless element.has_key?("ignore")
            invalid_keys << element["key"]
          end

          if invalid_keys.include?(element["key"]) && element.has_key?("append_to_tag")
            invalid_keys.delete(element["key"])
          end
        end

        element.keys.each do |k|
          # read and throw away to supress unread configuration warning
          element[k]
        end
      }

      if invalid_keys.size != 0
        raise ConfigError, "out_rewrite: 'add_prefix' or 'remove_prefix' option has been set. or finally 'append_to_tag' must be set in the rule section. Your invalid key(s) is(are) #{invalid_keys.uniq}"
      end
    end

    def start
      super
    end

    def shutdown
      super
    end

    def emit(tag, es, chain)
      @warn_msg = nil
      _tag = tag.clone

      if @remove_prefix and
        ((tag.start_with?(@removed_prefix_string) && tag.length > @removed_length) || tag == @remove_prefix)
        tag = tag[@removed_length..-1] || ''
      end

      if @add_prefix
        tag = tag && tag.length > 0 ? @added_prefix_string + tag : @add_prefix
      end

      es.each do |time, record|
        filtered_tag, record = rewrite(tag, record)
        if _tag != tag && filtered_tag && record
          Engine.emit(filtered_tag, time, record)
        else
          $log.warn "out_rewrite: #{@warn_msg}"
        end
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

      if !record.has_key?(key)
        @warn_msg = "Since there is no matching JSON key \"#{key}\", can't emit record #{record}, cause infinity looping. Check the rules of the setting where the pattern has become \"#{pattern}\""
        return [tag, record]
      end

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
        else
          @warn_msg = "Since there is no rule matches, can't emit record #{record}, cause infinity looping. If you want to emit even if do not match a rules, set the 'fallback' rule."
        end
      end

      [tag, record, last]
    end
  end
end
