# fluent-plugin-rewrite, a plugin for [Fluentd](http://fluentd.org)

## Component

### RewriteOutput

Output plugin to rewrite messages' tags/values along with pattern
matching and re-emit them.

## Synopsis

```
<match apache.log.**>
  type rewrite

  remove_prefix apache.log
  add_prefix    filtered

  <rule>
    key     path
    pattern \\?.+$
    replace
  </rule>
  <rule>
    key     path
    pattern (/[^/]+)\\?([^=]+)=(\\d)
    replace \\1/\\2/\\3
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
  <rule>
    key           is_loggged_in
    pattern       1
    append_to_tag true
    tag           user
  </rule>
</match>
```

## Configuration

### remove_prefix / add_prefix

```
remove_prefix apache.log
add_prefix    filtered
```

- remove_prefix: removes the string from a prefix of tag.
- add_prefix: prepend the string to a tag.

### rule: replace

For example, if you want to filter out query string form URL string:

```
<rule>
  key     path
  pattern \\?.+$
  replace
</rule>
```

It executes pattern matching against a value related with `key` and replaces it with empty string if it matches.

```
/foo?bar=baz -> /foo
```

This time, if you want to rewrite path string along with some pattern:

```
<rule>
  key     path
  pattern (/[^/]+)\\?([^=]+)=(\\d)
  replace \\1/\\2/\\3
</rule>
```

It executes pattern matching against a value related with `key` and replaces it with `replace` if it matches.

```
/foo?bar=1 -> /foo/bar/1
```

### rule: ignore

For example, if you want to skip a message which matches some pattern:

```
<rule>
  key     status
  pattern ^500$
  ignore  true
</rule>
```

It executes pattern matching against a value related with `key` and skip emitting the message if it matches.

### rule: append_to_tag

```
<rule>
  key           path
  pattern       ^\/(users|entries)
  append_to_tag true
</rule>
```

It executes pattern matching against a value related with `key` and append mathed strings to message tag. For example:

```
apache.log { "path" : "/users/antipop" }
```

the messabe above will be re-emmited as the message below:

```
apache.log.users { "path" : "/users/antipop" }
```

If you set `fallback` option like below:

```
<rule>
  key           path
  pattern       ^\/(users|entries)
  append_to_tag true
  fallback      others
</rule>
```

the value of `fallback` option will be appended to message tag.

```
apache.log { "path" : "/foo/bar" }
```

This time, the messabe above will be re-emmited as the message below:

```
apache.log.others { "path" : "/foo/bar" }
```

If `tag` option set,

```
<rule>
  key           is_loggged_in
  pattern       1
  append_to_tag true
  tag           user
</rule>
```

the value designated by `tag` will be appended to the original tag, that is:


```
test { "is_logged_in" => "1" }
```

will be

```
test.user { "is_logged_in" => "1" }
```

### rule: last

If you set `last` option to true, rewriting chain stops applying rule where the pattern matches first.

```
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
```

This rules will be applied like below:

```
{ "path" => "/foo" }
```

will be replaced with

```
{ "path" => "/bar" }
```

and the chain stops here. Therefore, the second rule is never
applied.

```
{ "path" => "/bar" }
```

will be replaced by the second rule as usual.

```
{ "path" => "/baz" }
```

## Installation

Add this line to your application's Gemfile:

    gem 'fluent-plugin-rewrite'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-rewrite

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

### Copyright

Copyright (c) 2012- Kentaro Kuribayashi (@kentaro)

### License

Apache License, Version 2.0
