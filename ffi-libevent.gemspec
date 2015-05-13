# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ffi/libevent/version'

Gem::Specification.new do |spec|
  spec.name          = "ffi-libevent"
  spec.version       = FFI::Libevent::VERSION
  spec.authors       = ["Alastair Pharo"]
  spec.email         = ["asppsa@gmail.com"]
  spec.description   = %q{Wrapper around libevent using Ruby FFI}
  spec.summary       = %q{Another libevent wrapper.  This one uses FFI}
  spec.homepage      = "https://github.com/asppsa/ffi-libevent"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'ffi'
  spec.add_dependency 'thread_safe'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end
