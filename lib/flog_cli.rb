require "rubygems"
require "optparse"
require "forwardable"

require "path_expander"
require "flog"

class FlogCLI
  extend Forwardable

  def_delegators :@flog, :average, :calculate, :each_by_score, :option
  def_delegators :@flog, :method_locations, :method_scores, :reset, :scores
  def_delegators :@flog, :threshold, :total_score, :no_method, :calculate_total_scores
  def_delegators :@flog, :max_method

  def self.run args = ARGV
    load_plugins

    expander = PathExpander.new args, "**/*.{rb,rake}"
    files = expander.process

    options = parse_options args

    flogger = new options
    flogger.flog(*files)
    flogger.report
  end

  ##
  # Loads all flog plugins. Files must be named "flog/*.rb".

  def self.load_plugins
    # TODO: I think I want to do this more like hoe's plugin system. Generalize?
    loaded, found = {}, {}

    Gem.find_files("flog/*.rb").reverse.each do |path|
      found[File.basename(path, ".rb").intern] = path
    end

    found.each do |name, plugin|
      next if loaded[name]
      begin
        warn "loading #{plugin}" # if $DEBUG
        loaded[name] = load plugin
      rescue LoadError => e
        warn "error loading #{plugin.inspect}: #{e.message}. skipping..."
      end
    end

    self.plugins.merge loaded

    names = Flog.constants.map {|s| s.to_s}.reject {|n| n =~ /^[A-Z_]+$/}

    names.each do |name|
      # next unless Hoe.plugins.include? name.downcase.intern
      mod = Flog.const_get(name)
      next if Class === mod
      warn "extend #{mod}" if $DEBUG
      # self.extend mod
    end
  end

  ##
  # Parse options in +args+ (defaults to ARGV).

  def self.parse_options args = ARGV
    option = {
      :quiet    => false,
      :continue => false,
      :parser   => RubyParser,
    }

    OptionParser.new do |opts|
      opts.separator "Standard options:"

      opts.on("-a", "--all", "Display all flog results, not top 60%.") do
        option[:all] = true
      end

      opts.on("-b", "--blame", "Include blame information for methods.") do
        option[:blame] = true
      end

      opts.on("-c", "--continue", "Continue despite syntax errors.") do
        option[:continue] = true
      end

      opts.on("-d", "--details", "Show method details.") do
        option[:details] = true
      end

      opts.on("-g", "--group", "Group and sort by class.") do
        option[:group] = true
      end

      opts.on("-h", "--help", "Show this message.") do
        puts opts
        exit
      end

      opts.on("-I dir1,dir2,dir3", Array, "Add to LOAD_PATH.") do |dirs|
        dirs.each do |dir|
          $: << dir
        end
      end

      opts.on("-m", "--methods-only", "Skip code outside of methods.") do
        option[:methods] = true
      end

      opts.on("-q", "--quiet", "Don't show parse errors.") do
        option[:quiet] = true
      end

      opts.on("-e", "--extended", "Put file:line on a separate line (for rubymine & friends).") do
        option[:extended] = true
      end

      opts.on("-s", "--score", "Display total score only.") do
        option[:score] = true
      end

      opts.on("-tN", "--threshold=N", Integer, "Set the report cutoff threshold (def: 60%).") do |n|
        option[:threshold] = n / 100.0
      end

      opts.on("-v", "--verbose", "Display progress during processing.") do
        option[:verbose] = true
      end

      opts.on("--18", "Use a ruby 1.8 parser.") do
        option[:parser] = Ruby18Parser
      end

      opts.on("--19", "Use a ruby 1.9 parser.") do
        option[:parser] = Ruby19Parser
      end

      next if self.plugins.empty?
      opts.separator "Plugin options:"

      extra = self.method_scores.grep(/parse_options/) - %w(parse_options)

      extra.sort.each do |msg|
        self.send msg, opts, option
      end

    end.parse! Array(args)

    option
  end

  ##
  # The known plugins for Flog. See Flog.load_plugins.

  def self.plugins
    @plugins ||= {}
  end

  ##
  # Flog the given files. Deals with "-", syntax errors, and
  # traversing subdirectories intelligently. Use PathExpander to
  # process dirs into files.

  def flog(*files)
    files << "-" if files.empty?
    @flog.flog(*files)
  end

  ##
  # Creates a new Flog instance with +options+.

  def initialize options = {}
    @flog = Flog.new options
  end

  ##
  # Output the report up to a given max or report everything, if nil.

  def output_details io, max = nil
    io.puts

    each_by_score max do |class_method, score, call_list|
      self.print_score io, class_method, score

      if option[:details] then
        call_list.sort_by { |k,v| -v }.each do |call, count|
          io.puts "  %6.1f:   %s" % [count, call]
        end
        io.puts
      end
    end
  end

  ##
  # Output the report, grouped by class/module, up to a given max or
  # report everything, if nil.

  def output_details_grouped io, threshold = nil
    calculate

    scores.sort_by { |_, n| -n }.each do |klass, total|
      io.puts

      io.puts "%8.1f: %s" % [total, "#{klass} total"]

      method_scores[klass].each do |name, score|
        self.print_score io, name, score
      end
    end
  end

  ##
  # Print out one formatted score.

  def print_score io, name, score
    location = method_locations[name]
    if location then
      sep = " "
      sep = "%-11s" % "\n" if option[:extended]
      io.puts "%8.1f: %-32s%s%s" % [score, name, sep, location]
    else
      io.puts "%8.1f: %s" % [score, name]
    end
  end

  ##
  # Report results to #io, STDOUT by default.

  def report(io = $stdout)
    io.puts "%8.1f: %s" % [total_score, "flog total"]
    io.puts "%8.1f: %s" % [average, "flog/method average"]

    return if option[:score]

    if option[:group] then
      output_details_grouped io, threshold
    else
      output_details io, threshold
    end
  ensure
    self.reset
  end
end
