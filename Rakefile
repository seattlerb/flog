# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs("../../ParseTree/dev/lib",
                     "../../RubyInline/dev/lib",
                     "../../sexp_processor/dev/lib",
                     "../../ZenTest/dev/lib",
                     "../../minitest/dev/lib",
                     "lib")

require 'flog'

Hoe.new('flog', Flog::VERSION) do |flog|
  flog.rubyforge_name = 'seattlerb'

  flog.developer('Ryan Davis', 'ryand-ruby@zenspider.com')

  flog.extra_deps << ['sexp_processor', '~> 3.0']
  flog.extra_deps << ['ruby_parser',    '~> 1.1.0']

  flog.testlib = :minitest
end


# vim: syntax=Ruby
