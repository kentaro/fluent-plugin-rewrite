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
        pattern \\?.+$
      </rule>
      <to_be_ignored>
        key bar
        pattern \\?.+$
      </to_be_ignored>
      <rule>
        key baz
        pattern \\?.+$
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
    d1 = create_driver(%[
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

    d1.run do
      d1.emit({ "path" => "/foo?bar=1" })
      d1.emit({ "path" => "/foo?bar=1", "status" => "500" })
      d1.emit({ "path" => "/users/antipop" })
      d1.emit({ "path" => "/users/kentaro" })
      d1.emit({ "path" => "/entries/1" })
    end
    emits = d1.emits

    assert_equal 4, emits.size
    assert_equal('filtered.others', emits[0][0])
    assert_equal({ "path" => "/foo" }, emits[0][2])
    assert_equal('filtered.users', emits[1][0])
    assert_equal({ "path" => "/users/antipop" }, emits[1][2])
    assert_equal('filtered.users', emits[2][0])
    assert_equal({ "path" => "/users/kentaro" }, emits[2][2])
    assert_equal('filtered.entries', emits[3][0])
    assert_equal({ "path" => "/entries/1" }, emits[3][2])

    d2 = create_driver(%[
      add_prefix filtered

      <rule>
        key     path
        pattern \\?.+$
        replace
      </rule>
    ])
    d2.run do
      d2.emit({ "path" => "/foo?bar=1" })
    end 
    emits = d2.emits

    assert_equal 1, emits.size
    assert_equal('filtered.test', emits[0][0])
    assert_equal({ "path" => "/foo" }, emits[0][2])

    d3 = create_driver(%[
      <rule>
        key     path
        pattern \\?.+$
        replace
      </rule>
    ])
    d3.run do
      d3.emit({ "path" => "/foo?bar=1" })
    end
    emits = d3.emits

    assert_equal 0, emits.size
    assert_equal(
      "Drop record \{\"path\"=>\"/foo\"\} tag 'test' was not replaced. Can't emit record, cause infinity looping.",
      d3.instance.warn_msg
    )

    d4 = create_driver(%[
      <rule>
        key     path
        pattern ^\/(users|entries)
      </rule>
    ])
    d4.run do
      d4.emit({ "path" => "/pull-requester/studio3104" })
    end
    emits = d4.emits

    assert_equal 0, emits.size
    assert_equal(
      "Since there is no rule matches, can't emit record \{\"path\"=>\"/pull-requester/studio3104\"\}, cause infinity looping. If you want to emit even if do not match a rules, set the 'fallback' rule.",
      d4.instance.warn_msg
    )

    d5 = create_driver(%[
      <rule>
        key     status
        pattern ^500
      </rule>
    ])
    d5.run do
      d5.emit({ "path" => "/foo?bar=1" })
    end
    emits = d5.emits

    assert_equal 0, emits.size
    assert_equal(
      "Since there is no matching JSON key \"status\", can't emit record {\"path\"=>\"/foo?bar=1\"}, cause infinity looping. Check the rules of the setting where the pattern has become \"^500\"",
      d5.instance.warn_msg
    )
  end
end
