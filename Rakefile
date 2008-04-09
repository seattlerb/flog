# -*- ruby -*-

require 'rubygems'
require 'hoe'

$: << '../../ParseTree/dev/lib' << '../../RubyInline/dev/lib'

require './lib/flog'

Hoe.new('flog', Flog::VERSION) do |flog|
  flog.rubyforge_name = 'seattlerb'

  flog.developer('Ryan Davis', 'ryand-ruby@zenspider.com')

  flog.extra_deps << ["ParseTree", '>= 2.0.1']
end

# vim: syntax=Ruby
