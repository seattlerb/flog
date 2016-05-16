require 'rake/tasklib'

class FlogTask < Rake::TaskLib
  ##
  # The name of the task. Defaults to :flog

  attr_accessor :name

  ##
  # What directories to operate on. Sensible defaults.

  attr_accessor :dirs

  ##
  # Threshold to fail the task at. Default 200.

  attr_accessor :threshold

  ##
  # Verbosity of output. Defaults to rake's trace (-t) option.

  attr_accessor :verbose

  ##
  # Method to use to score. Defaults to :total_score

  attr_accessor :method

  ##
  # Creates a new FlogTask instance with given +name+, +threshold+,
  # +dirs+, and +method+.

  def initialize name = :flog, threshold = 200, dirs = nil, method = nil, methods_only = false
    @name         = name
    @dirs         = dirs || %w(app bin lib spec test)
    @threshold    = threshold
    @method       = method || :total_score
    @verbose      = Rake.application.options.trace
    @methods_only = methods_only

    yield self if block_given?

    @dirs.reject! { |f| ! File.directory? f }

    define
  end

  ##
  # Defines the flog task.

  def define
    desc "Analyze for code complexity in: #{dirs.join(', ')}"
    task name do
      require "flog_cli"
      flog = FlogCLI.new :continue => true, :quiet => true, :methods => @methods_only

      expander = PathExpander.new dirs, "**/*.{rb,rake}"
      files = expander.process

      flog.flog(*files)

      desc, score = flog.send method
      desc, score = "total", desc unless score # total only returns a number

      flog.report if verbose

      raise "Flog score for #{desc} is too high! #{score} > #{threshold}" if
        score > threshold
    end

    self
  end
end
