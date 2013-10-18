# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs("../../ruby_parser/dev/lib",
                     "../../RubyInline/dev/lib",
                     "../../sexp_processor/dev/lib",
                     "../../ZenTest/dev/lib",
                     "../../minitest/dev/lib",
                     "lib")

Hoe.plugin :seattlerb

Hoe.spec 'flog' do
  developer 'Ryan Davis', 'ryand-ruby@zenspider.com'

  self.rubyforge_name = 'seattlerb'

  self.flog_method = :max_method
  self.flog_threshold = timebomb 150, 50, '2013-11-01', '2012-11-01'

  dependency "sexp_processor", "~> 4.4"
  dependency "ruby_parser",    ["~> 3.1", "> 3.1.0"]
end

task :debug do
  require "flog_cli"

  class FlogCLI
    def_delegators :@flog, :flog_ruby
  end

  file = ENV["F"]
  ruby = ENV["R"]

  flog = FlogCLI.new :parser => RubyParser

  if file then
    flog.flog file
  else
    flog.flog_ruby ruby, "-"
    flog.calculate_total_scores
  end

  flog.report
end

# vim: syntax=ruby
