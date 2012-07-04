require 'test_helper'

class RewriteOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def create_driver(conf, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::RewriteOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver(%[
      remove_prefix test
      add_prefix    filtered

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

    assert_equal "test",     d.instance.remove_prefix
    assert_equal "filtered", d.instance.add_prefix
    assert_equal 2, d.instance.rules.size
  end

  def test_rewrite_replace
    d1 = create_driver(%[
      <rule>
        key     path
        pattern \\?.+$
        replace
      </rule>
    ])

    assert_equal(
      [ "test", { "path" => "/foo" } ],
      d1.instance.rewrite("test", { "path" => "/foo?bar=1" })
    )

    d2 = create_driver(%[
      <rule>
        key     path
        pattern (/[^/]+)\\?([^=]+)=(\\d)
        replace \\1/\\2/\\3
      </rule>
    ])

    assert_equal(
      [ "test", { "path" => "/foo/bar/1" } ],
      d2.instance.rewrite("test", { "path" => "/foo?bar=1" })
    )
  end

  def test_rewrite_ignore
    d1 = create_driver(%[
      <rule>
        key     status
        pattern ^500$
        ignore  true
      </rule>
    ])

    assert_equal(
      nil,
      d1.instance.rewrite("test", { "status" => "500" })
    )

    d2 = create_driver(%[
      <rule>
        key     status
        pattern ^(?!200)\\d+$
        ignore  true
      </rule>
    ])

    assert_equal(
      [ "test", { "status" => "200" } ],
      d2.instance.rewrite("test", { "status" => "200" })
    )
    %w[301 404 500].each do |status|
      assert_equal(
        nil,
        d2.instance.rewrite("test", { "status" => status })
      )
    end

    d3 = create_driver(%[
      <rule>
        key     flag
        pattern ^$
        ignore  true
      </rule>
    ])

    assert_equal(
      nil,
      d3.instance.rewrite("test", { "flag" => "" })
    )
  end

  def test_rewrite_append_tag
    d1 = create_driver(%[
      <rule>
        key           path
        pattern       ^\/(users|entries)
        append_to_tag true
      </rule>
    ])

    assert_equal(
      [ "test.users", { "path" => "/users/antipop" } ],
      d1.instance.rewrite("test", { "path" => "/users/antipop" })
    )
    assert_equal(
      [ "test", { "path" => "/unmatched/path" } ],
      d1.instance.rewrite("test", { "path" => "/unmatched/path" })
    )

    d2 = create_driver(%[
      <rule>
        key           path
        pattern       ^\/(users|entries)
        append_to_tag true
        fallback      others
      </rule>
    ])

    assert_equal(
      [ "test.users", { "path" => "/users/antipop" } ],
      d2.instance.rewrite("test", { "path" => "/users/antipop" })
    )
    assert_equal(
      [ "test.others", { "path" => "/unmatched/path" } ],
      d2.instance.rewrite("test", { "path" => "/unmatched/path" })
    )

    d3 = create_driver(%[
      <rule>
        key           is_logged_in
        pattern       1
        append_to_tag true
        tag           user
      </rule>
    ])

    assert_equal(
      [ "test.user", { "is_logged_in" => "1" } ],
      d3.instance.rewrite("test", { "is_logged_in" => "1" })
    )
    assert_equal(
      [ "test", { "is_logged_in" => "0" } ],
      d3.instance.rewrite("test", { "is_logged_in" => "0" })
    )

    d4 = create_driver(%[
      <rule>
        key           path
        pattern       ^\/(users|entries)
        append_to_tag true
      </rule>
    ])

    assert_equal(
      [ "test.users", { "path" => "/users/antipop" } ],
      d4.instance.rewrite("test", { "path" => "/users/antipop" })
    )

    d5 = create_driver(%[
      <rule>
        key           is_logged_in
        pattern       1
        append_to_tag true
        tag           user
      </rule>
    ])

    assert_equal(
      [ "test.user", { "is_logged_in" => "1" } ],
      d5.instance.rewrite("test", { "is_logged_in" => "1" })
    )
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
      [ "test", { "path" => "/bar" } ],
      d.instance.rewrite("test", { "path" => "/foo" })
    )
    assert_equal(
      [ "test", { "path" => "/baz" } ],
      d.instance.rewrite("test", { "path" => "/bar" })
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
      <rule>
        key           path
        pattern       ^\/(users|entries)
        append_to_tag true
        fallback      others
      </rule>
    ])

    assert_equal(
      [ "test.others", { "path" => "/foo" } ],
      d.instance.rewrite("test", { "path" => "/foo?bar=1" })
    )
    assert_equal(
      [ "test.users", { "path" => "/users/antipop" } ],
      d.instance.rewrite("test", { "path" => "/users/antipop?hoge=1" })
    )
    assert_equal(
      nil,
      d.instance.rewrite("test", { "path" => "/foo?bar=1", "status" => "500" })
    )
  end

  def test_emit
    d = create_driver(%[
      remove_prefix test
      add_prefix    filtered

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
      <rule>
        key           path
        pattern       ^\/(users|entries)
        append_to_tag true
        fallback      others
      </rule>
    ])

    d.run do
      d.emit({ "path" => "/foo?bar=1" })
      d.emit({ "path" => "/foo?bar=1", "status" => "500" })
      d.emit({ "path" => "/users/antipop" })
      d.emit({ "path" => "/users/kentaro" })
      d.emit({ "path" => "/entries/1" })
    end
    emits = d.emits

    assert_equal 4, emits.size
    assert_equal('filtered.others', emits[0][0])
    assert_equal({ "path" => "/foo" }, emits[0][2])
    assert_equal('filtered.users', emits[1][0])
    assert_equal({ "path" => "/users/antipop" }, emits[1][2])
    assert_equal('filtered.users', emits[2][0])
    assert_equal({ "path" => "/users/kentaro" }, emits[2][2])
    assert_equal('filtered.entries', emits[3][0])
    assert_equal({ "path" => "/entries/1" }, emits[3][2])
  end
end
