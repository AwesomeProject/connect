require File.expand_path('../lib/suse/connect/version', __FILE__)
require 'date'

Gem::Specification.new do |gem|
  gem.name        = 'suse-connect'
  gem.version     = SUSE::Connect::VERSION
  gem.date        = Date.today.to_s
  gem.summary     = 'SUSE Connect utility to register a system with the SUSE Customer Center'
  gem.description = 'This package provides a command line tool and rubygem library for connecting a client system ' \
                    'to the SUSE Customer Center. It will connect the system to your product subscriptions and enable ' \
                    'the product repositories/services locally.'
  gem.authors     = ['SUSE Customer Center Team']
  gem.license     = 'LGPL-2.1'
  gem.email       = 'happy-customer@suse.de'
  gem.homepage    = 'https://github.com/SUSE/connect'
  gem.files       = Dir['{bin,lib}/**/*', 'README*', 'LICENSE*', 'LGPL*'] & `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  gem.executables << 'SUSEConnect'
  gem.required_ruby_version = '>= 2.0'
end
