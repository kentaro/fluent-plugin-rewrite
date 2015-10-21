module Fluent
  class RewriteFilter < Filter
    Fluent::Plugin.register_filter('rewrite', self)

    attr_reader  :rules

    def configure(conf)
      super

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

    def filter_stream(tag, es)
      new_es = MultiEventStream.new

      es.each do |time, record|
        record = rewrite(record)
        new_es.add(time, record) if record
      end

      new_es
    end

    def rewrite(record)
      rules.each do |rule|
        record, last = apply_rule(rule, record)

        break  if last
        return if !record
      end

      [record]
    end

    def apply_rule(rule, record)
      key        = rule["key"]
      pattern    = rule["pattern"]
      last       = nil

      return [record] if !key || !record.has_key?(key)
      return [record] unless pattern

      if matched = record[key].match(rule["regex"])
        return if rule["ignore"]

        if rule["replace"]
          replace = rule["replace"]
          record[key] = record[key].gsub(rule["regex"], replace)
        end

        if rule["last"]
          last = true
        end
      end

      [record, last]
    end
  end if defined?(Filter)
end
