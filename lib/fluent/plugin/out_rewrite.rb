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

      @rules = conf.elements.select { |element|
        element.name == 'rule'
      }.each { |element|
        if element["pattern"] && element["key"]
          element["regex"] = Regexp.new(element["pattern"])
        else
          raise ConfigError, "out_rewrite: In the rules section, must set both 'key' and 'pattern'."
        end

        element["append_to_tag"] = true if element["tag"] || element["fallback"]

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
        if filtered_tag && record && tag != filtered_tag
          Engine.emit(filtered_tag, time, record)
        else
          $log.warn @warn_msg
          @warn_msg = nil
        end
      end

      chain.next
    end

    def rewrite(tag, record)
      _tag = tag.clone
      rules.each do |rule|
        tag, record, last = apply_rule(rule, tag, record)

        break  if last
        return if !tag && !record
      end

      @warn_msg = "out_rewrite: Drop record #{record} tag '#{tag}' was not replaced. Can't emit record, cause infinity looping." if _tag == tag && !@warn_msg
      [tag, record]
    end

    def apply_rule(rule, tag, record)
      tag_prefix = tag && tag.length > 0 ? "." : ""
      key        = rule["key"]
      pattern    = rule["pattern"]
      last       = nil

      if !record.has_key?(key)
        @warn_msg = "out_rewrite: Since there is no matching JSON key \"#{key}\", can't emit record #{record}, cause infinity looping. Check the rules of the setting where the pattern has become \"#{pattern}\""
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
          @warn_msg = "out_rewrite: Since there is no rule matches, can't emit record #{record}, cause infinity looping. If you want to emit even if do not match a rules, set the 'fallback' rule."
        end
      end

      [tag, record, last]
    end
  end
end
