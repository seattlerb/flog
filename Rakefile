# -*- ruby -*-

require 'rubygems'
require 'hoe'

$: << '../../ParseTree/dev/lib' << '../../RubyInline/dev/lib'

require './lib/flog'

Hoe.new('flog', Flog::VERSION) do |p|
  p.rubyforge_name = 'seattlerb'
  p.summary = p.paragraphs_of('README.txt', 2).first
  p.description = p.paragraphs_of('README.txt', 2, 6).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[2..-1].map {|u| u.strip }
  p.changes = p.paragraphs_of('History.txt', 1).join("\n\n")

  p.extra_deps << ["ParseTree", '>= 2.0.1']
end

# vim: syntax=Ruby
