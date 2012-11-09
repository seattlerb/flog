class FlogTask < Rake::TaskLib
  attr_accessor :name
  attr_accessor :dirs
  attr_accessor :threshold
  attr_accessor :verbose
  attr_accessor :method

  def initialize name = :flog, threshold = 200, dirs = nil, method = nil
    @name      = name
    @dirs      = dirs || %w(app bin lib spec test)
    @threshold = threshold
    @method    = method || :total
    @verbose   = Rake.application.options.trace

    yield self if block_given?

    @dirs.reject! { |f| ! File.directory? f }

    define
  end

  def define
    desc "Analyze for code complexity in: #{dirs.join(', ')}"
    task name do
      require "flog"
      flog = Flog.new :continue => true, :quiet => true
      flog.flog(*dirs)

      desc, score = flog.send method
      desc, score = "total", desc unless score # total only returns a number

      flog.report if verbose

      raise "Flog score for #{desc} is too high! #{score} > #{threshold}" if
        score > threshold
    end

    self
  end
end
