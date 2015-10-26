module Fluent
  class RewriteFilter < Filter
    Fluent::Plugin.register_filter('rewrite', self)

    attr_reader  :rules, :rewrite_rule

    def configure(conf)
      require 'fluent/plugin/rewrite_rule'

      super

      @rewrite_rule = RewriteRule.new(self, conf)
    end

    def filter_stream(tag, es)
      new_es = MultiEventStream.new

      es.each do |time, record|
        record = @rewrite_rule.rewrite(record)
        new_es.add(time, record) if record
      end

      new_es
    end
  end if defined?(Filter)
end
