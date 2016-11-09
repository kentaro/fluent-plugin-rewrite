module Fluent
  class RewriteOutput < Output
    Fluent::Plugin.register_output('rewrite', self)

    # Define `router` method of v0.12 to support v0.10.57 or earlier
    unless method_defined?(:router)
      define_method("router") { Engine }
    end

    config_param :remove_prefix,   :string, :default => nil
    config_param :add_prefix,      :string, :default => nil
    config_param :enable_warnings, :bool,   :default => false

    attr_reader  :rewrite_rule

    def configure(conf)
      require 'fluent/plugin/rewrite_rule'

      super

      if @remove_prefix
        @removed_prefix_string = @remove_prefix + '.'
        @removed_length = @removed_prefix_string.length
      end
      if @add_prefix
        @added_prefix_string = @add_prefix + '.'
      end

      @rewrite_rule = RewriteRule.new(self, conf)
    end

    def start
      super
    end

    def shutdown
      super
    end

    def emit(tag, es, chain)
      _tag = tag.clone

      if @remove_prefix and
        ((tag.start_with?(@removed_prefix_string) && tag.length > @removed_length) || tag == @remove_prefix)
        tag = tag[@removed_length..-1] || ''
      end

      if @add_prefix
        tag = tag && tag.length > 0 ? @added_prefix_string + tag : @add_prefix
      end

      es.each do |time, record|
        filtered_tag, record = @rewrite_rule.rewrite(tag, record)
        if filtered_tag && record && _tag != filtered_tag
          router.emit(filtered_tag, time, record)
        else
          if @enable_warnings
            $log.warn "Can not emit message because the tag(#{tag}) has not changed. Dropped record #{record}"
          end
        end
      end

      chain.next
    end
  end
end
