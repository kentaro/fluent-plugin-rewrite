require 'test_helper'

class RewriteFilterTest < Test::Unit::TestCase
  def setup
    omit("These tests require Fluentd v0.12 or later.") unless defined?(Fluent::Filter)

    Fluent::Test.setup
  end

  def create_driver(conf, tag = 'test')
    Fluent::Test::FilterTestDriver.new(Fluent::RewriteFilter, tag).configure(conf)
  end

  def test_configure
    d = create_driver(%[
      <rule>
        key foo
      </rule>
      <to_be_ignored>
        key bar
      </to_be_ignored>
      <rule>
        key baz
      </rule>
    ])

    assert_equal 2, d.instance.rewrite_rule.rules.size
  end

  class TestRewrite < self
    def test_replace
      d = create_driver(%[
        <rule>
          key     path
          pattern \\?.+$
          replace
        </rule>
      ])

      assert_equal(
        [ { "path" => "/foo" } ],
        d.instance.rewrite_rule.rewrite({ "path" => "/foo?bar=1" })
      )
    end

    def test_replace_with_capture
      d = create_driver(%[
        <rule>
          key     path
          pattern (/[^/]+)\\?([^=]+)=(\\d)
          replace \\1/\\2/\\3
        </rule>
      ])

      assert_equal(
        [ { "path" => "/foo/bar/1" } ],
        d.instance.rewrite_rule.rewrite({ "path" => "/foo?bar=1" })
      )
    end
  end

  class TestRewriteIgnore < self
    def test_pattern
      d = create_driver(%[
        <rule>
          key     status
          pattern ^500$
          ignore  true
        </rule>
      ])

      assert_equal(
        nil,
        d.instance.rewrite_rule.rewrite({ "status" => "500" })
      )
    end

    def test_negate_pattern
      d = create_driver(%[
        <rule>
          key     status
          pattern ^(?!200)\\d+$
          ignore  true
        </rule>
      ])

      assert_equal(
        [ { "status" => "200" } ],
        d.instance.rewrite_rule.rewrite({ "status" => "200" })
      )
      %w[301 404 500].each do |status|
        assert_equal(
          nil,
          d.instance.rewrite_rule.rewrite({ "status" => status })
        )
      end
    end

    def test_entire_ignore
      d = create_driver(%[
        <rule>
          key     flag
          pattern ^$
          ignore  true
        </rule>
      ])

      assert_equal(
        nil,
        d.instance.rewrite_rule.rewrite({ "flag" => "" })
      )
    end
  end

  def test_last
    d = create_driver(%[
      <rule>
        key     path
        pattern ^/foo$
        replace /bar
        last    true
      </rule>
      <rule>
        key     path
        pattern ^/bar$
        replace /baz
      </rule>
    ])

    assert_equal(
      [ { "path" => "/bar" } ],
      d.instance.rewrite_rule.rewrite({ "path" => "/foo" })
    )
    assert_equal(
      [ { "path" => "/baz" } ],
      d.instance.rewrite_rule.rewrite({ "path" => "/bar" })
    )
  end

  def test_rewrite_rules
    d = create_driver(%[
      <rule>
        key     path
        pattern \\?.+$
        replace
      </rule>
      <rule>
        key     status
        pattern ^500$
        ignore  true
      </rule>
    ])

    assert_equal(
      [ { "path" => "/foo" } ],
      d.instance.rewrite_rule.rewrite({ "path" => "/foo?bar=1" })
    )
    assert_equal(
      [ { "path" => "/users/antipop" } ],
      d.instance.rewrite_rule.rewrite({ "path" => "/users/antipop?hoge=1" })
    )
    assert_equal(
      nil,
      d.instance.rewrite_rule.rewrite({ "path" => "/foo?bar=1", "status" => "500" })
    )
  end

  class TestFilter < self
    def test_with_multiple_rules
      d = create_driver(%[
        <rule>
          key     path
          pattern \\?.+$
          replace
        </rule>
        <rule>
          key     status
          pattern ^500$
          ignore  true
        </rule>
      ])

      d.run do
        d.filter({ "path" => "/foo?bar=1" })
        d.filter({ "path" => "/foo?bar=1", "status" => "500" })
        d.filter({ "path" => "/users/antipop" })
        d.filter({ "path" => "/users/kentaro" })
      end
      filtered = d.filtered_as_array

      assert_equal 3, filtered.size
      assert_equal('test', filtered[0][0])
      assert_equal([{ "path" => "/foo" }], filtered[0][2])
      assert_equal('test', filtered[1][0])
      assert_equal([{ "path" => "/users/antipop" }], filtered[1][2]) # nothing to do
      assert_equal('test', filtered[2][0])
      assert_equal([{ "path" => "/users/kentaro" }], filtered[2][2]) # nothing to do
    end

    def test_remove_query_params
      d = create_driver(%[
        <rule>
          key     path
          pattern \\?.+$
          replace
        </rule>
      ])
      d.run do
        d.filter({ "path" => "/foo?bar=1" })
      end
      filtered = d.filtered_as_array

      assert_equal 1, filtered.size
      assert_equal('test', filtered[0][0])
      assert_equal([{ "path" => "/foo" }], filtered[0][2])
    end
  end
end
