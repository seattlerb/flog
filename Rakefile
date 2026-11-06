# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.add_include_dirs("../../sexp_processor/dev/lib",
                     "../../ZenTest/dev/lib",
                     "../../path_expander/dev/lib",
                     "lib")

Hoe.plugin :seattlerb
Hoe.plugin :isolate_binaries
Hoe.plugin :rdoc
Hoe.plugin :bundler

Hoe.spec 'flog' do
  developer 'Ryan Davis', 'ryand-ruby@zenspider.com'

  self.flog_method = :max_method
  self.flog_threshold = timebomb 150, 50, '2013-11-01', '2012-11-01'

  license "MIT"

  dependency "sexp_processor", "~> 4.8"
  dependency "prism",         [">= 1.9", "< 3"]
  dependency "path_expander",  "~> 2.0"
end

task :debug do
  require "flog_cli"

  class FlogCLI
    def_delegators :@flog, :flog_ruby
  end

  file = ENV["F"]
  ruby = ENV["R"]
  details = ENV["D"]
  continue = ENV["C"]

  flog = FlogCLI.new

  flog.option[:details] = true if details
  flog.option[:continue] = true if continue

  if file then
    if File.directory? file then # quick hack to get directory scanning going
      argv = [file]
      argv.unshift "-v" if ENV["V"]

      FlogCLI.run argv, flog.option
      exit 0
    end
    flog.flog file
  elsif ruby
    flog.flog_ruby ruby, "-"
    flog.calculate_total_scores
  else
    flog.flog
    flog.calculate_total_scores
  end

  flog.report
end

# vim: syntax=ruby
