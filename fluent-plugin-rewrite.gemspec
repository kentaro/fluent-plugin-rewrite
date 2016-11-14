Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-rewrite"
  gem.version       = '0.1.0'
  gem.authors       = ["Kentaro Kuribayashi"]
  gem.email         = ["kentarok@gmail.com"]
  gem.homepage      = "http://github.com/kentaro/fluent-plugin-rewrite"
  gem.description   = %q{Fluentd plugin to rewrite tags/values along with pattern matching and re-emit them.}
  gem.summary       = %q{Fluentd plugin to rewrite tags/values along with pattern matching and re-emit them.}
  gem.license       = 'MIT'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_development_dependency "rake"
  gem.add_development_dependency "test-unit", "~> 3.1"
  gem.add_development_dependency "appraisal"
  gem.add_runtime_dependency     "fluentd", [">= 0.14.8", "< 2"]
end
