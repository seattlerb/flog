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

  dependency 'sexp_processor', '~> 4.0'
  dependency 'ruby_parser',    '~> 3.0'
end

task :debug do
  require "flog"

  file = ENV["F"] || "-"
  ruby = file == "-" ? ENV["R"] : File.read(file)

  @flog = Flog.new :parser => RubyParser
  @flog.flog_ruby ruby, file
  @flog.report
end

# vim: syntax=ruby
