class FlogTask < Rake::TaskLib
  attr_accessor :name
  attr_accessor :dirs
  attr_accessor :threshold
  attr_accessor :verbose

  def initialize name = :flog, threshold = 200, dirs = nil
    @name      = name
    @dirs      = dirs || %w(app bin lib spec test)
    @threshold = threshold
    @verbose   = Rake.application.options.trace

    yield self if block_given?

    @dirs.reject! { |f| ! File.directory? f }

    define
  end

  def define
    desc "Analyze for code complexity in: #{dirs.join(', ')}"
    task name do
      require "flog"
      flog = Flog.new
      flog.flog(*dirs)
      flog.report if verbose

      raise "Flog total too high! #{flog.total} > #{threshold}" if
        flog.total > threshold
    end
    self
  end
end
