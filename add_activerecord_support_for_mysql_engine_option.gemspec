# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'add_activerecord_support_for_mysql_engine_option/version'

Gem::Specification.new do |spec|
  spec.name          = "add_activerecord_support_for_mysql_engine_option"
  spec.version       = AddActiverecordSupportForMysqlEngineOption::VERSION
  spec.authors       = ["Jon Plaut"]
  spec.email         = ["jp@tangerinesymphony.net"]
  spec.description   = %q{Add support for engine option in rails mysql migrations}
  spec.summary       = %q{Add support for engine option in rails mysql migrations}
  spec.homepage      = "https://github.com/jplaut/add_activerecord_support_for_mysql_engine_option"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
end
