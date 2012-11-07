class FlogTask < Rake::TaskLib
  attr_accessor :name
  attr_accessor :dirs
  attr_accessor :threshold
  attr_accessor :verbose
  attr_accessor :fail_method
  attr_accessor :parser

  def initialize name = :flog, threshold = 200, dirs = nil
    @name      = name
    @dirs      = dirs || %w(app bin lib spec test)
    @threshold = threshold
    @fail_method = :total
    @verbose   = Rake.application.options.trace
    @parser    = :RubyParser

    yield self if block_given?

    @dirs.reject! { |f| ! File.directory? f }

    define
  end

  def define
    desc "Analyze for code complexity in: #{dirs.join(', ')}"
    task name do
      require "flog"
      flog = Flog.new
      flog.options[:parser] = case parser
      when :RubyParser
        RubyParser
      when :Ruby18Parser
        Ruby18Parser
      when :Ruby19Parser
        Ruby19Parser
      else
        raise "Unknown parser"
      end
      flog.flog(*dirs)
       max_method, max_score = flog.max_method #need to grab these values before report resets them.
      flog.report if verbose

      case fail_method
      when :total
        raise "Flog total too high! #{flog.total} > #{threshold}" if
          flog.total > threshold
      when :max_method
        raise "Flog score for method #{max_method} too high! #{max_score} > #{threshold}" if max_score > threshold
      else
        raise "Unknow value of fail_method"
      end
    end
    
    self
  end
end
