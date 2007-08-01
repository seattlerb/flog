# -*- ruby -*-

require 'rubygems'
require 'hoe'
require './lib/flog'

Hoe.new('flog', Flog::VERSION) do |p|
  p.rubyforge_name = 'seattlerb'
  p.summary = p.paragraphs_of('README.txt', 2).first
  p.description = p.paragraphs_of('README.txt', 2, 6).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/).last.strip
  p.changes = p.paragraphs_of('History.txt', 1).join("\n\n")

  p.extra_deps << ["ParseTree", '>= 2.0.0']
end

# vim: syntax=Ruby
