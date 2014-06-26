# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smart_s3_sync/version'

Gem::Specification.new do |spec|
  spec.name          = "smart_s3_sync"
  spec.version       = SmartS3Sync::VERSION
  spec.authors       = ["Chris Rhoden"]
  spec.email         = ["chris@prx.org"]
  spec.description   = %q{Intelligent syncing from Cloud providers when duplicate content abounds.}
  spec.summary       = %q{Intelligent syncing from Cloud providers when duplicate content abounds.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "fog"
  spec.add_dependency "sqlite3"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
