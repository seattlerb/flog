require 'rubygems'
require 'sexp_processor'
require 'ruby_parser'
require 'optparse'
require 'timeout'

class File
  RUBY19 = "<3".respond_to? :encoding unless defined? RUBY19 # :nodoc:

  class << self
    alias :binread :read unless RUBY19
  end
end

class Flog < SexpProcessor
  VERSION = "3.2.3" # :nodoc:

  ##
  # Cut off point where the report should stop unless --all given.

  THRESHOLD = 0.60

  ##
  # The scoring system hash. Maps node type to score.

  SCORES = Hash.new 1

  ##
  # Names of nodes that branch.

  BRANCHING = [ :and, :case, :else, :if, :or, :rescue, :until, :when, :while ]

  ##
  # Various non-call constructs

  OTHER_SCORES = {
    :alias          => 2,
    :assignment     => 1,
    :block          => 1,
    :block_pass     => 1,
    :branch         => 1,
    :lit_fixnum     => 0.25,
    :sclass         => 5,
    :super          => 1,
    :to_proc_icky!  => 10,
    :to_proc_lasgn  => 15,
    :to_proc_normal => 5,
    :yield          => 1,
  }

  ##
  # Eval forms

  SCORES.merge!(:define_method => 5,
                :eval          => 5,
                :module_eval   => 5,
                :class_eval    => 5,
                :instance_eval => 5)

  ##
  # Various "magic" usually used for "clever code"

  SCORES.merge!(:alias_method               => 2,
                :extend                     => 2,
                :include                    => 2,
                :instance_method            => 2,
                :instance_methods           => 2,
                :method_added               => 2,
                :method_defined?            => 2,
                :method_removed             => 2,
                :method_undefined           => 2,
                :private_class_method       => 2,
                :private_instance_methods   => 2,
                :private_method_defined?    => 2,
                :protected_instance_methods => 2,
                :protected_method_defined?  => 2,
                :public_class_method        => 2,
                :public_instance_methods    => 2,
                :public_method_defined?     => 2,
                :remove_method              => 2,
                :send                       => 3,
                :undef_method               => 2)

  ##
  # Calls that are ALMOST ALWAYS ABUSED!

  SCORES.merge!(:inject => 2)

  @@no_class  = :main
  @@no_method = :none

  # :stopdoc:
  attr_accessor :multiplier
  attr_reader :calls, :option, :class_stack, :method_stack, :mass, :sclass
  attr_reader :method_locations
  attr_reader :methods, :scores

  # :startdoc:

  ##
  # The known plugins for Flog. See Flog.load_plugins.

  def self.plugins
    @plugins ||= {}
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
  # Expands +*dirs+ to all files within that match ruby and rake extensions.
  # --
  # REFACTOR: from flay

  def self.expand_dirs_to_files *dirs
    extensions = %w[rb rake]

    dirs.flatten.map { |p|
      if File.directory? p then
        Dir[File.join(p, '**', "*.{#{extensions.join(',')}}")]
      else
        p
      end
    }.flatten.sort
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

      opts.on("-s", "--score", "Display total score only.") do
        option[:score] = true
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

      extra = self.methods.grep(/parse_options/) - %w(parse_options)

      extra.sort.each do |msg|
        self.send msg, opts, option
      end

    end.parse! Array(args)

    option
  end

  ##
  # Add a score to the tally. Score can be predetermined or looked up
  # automatically. Uses multiplier for additional spankings.
  # Spankings!

  def add_to_score name, score = OTHER_SCORES[name]
    @calls[signature][name] += score * @multiplier
  end

  ##
  # really?

  def average
    return 0 if calls.size == 0
    total / calls.size
  end

  ##
  # Iterate over the calls sorted (descending) by score.

  def each_by_score max = nil
    my_totals = totals
    current   = 0

    calls.sort_by { |k,v| -my_totals[k] }.each do |class_method, call_list|
      score = my_totals[class_method]

      yield class_method, score, call_list

      current += score
      break if max and current >= max
    end
  end

  ##
  # Flog the given files or directories. Smart. Deals with "-", syntax
  # errors, and traversing subdirectories intelligently.

  def flog(*files_or_dirs)
    files = Flog.expand_dirs_to_files(*files_or_dirs)

    files.each do |file|
      next unless file == '-' or File.readable? file

      ruby = file == '-' ? $stdin.read : File.binread(file)

      flog_ruby ruby, file
    end
  end

  ##
  # Flog the given ruby source, optionally using file to provide paths
  # for methods. Smart. Handles syntax errors and timeouts so you
  # don't have to.

  def flog_ruby ruby, file="-", timeout = 10
    flog_ruby! ruby, file, timeout
  rescue Timeout::Error
    warn "TIMEOUT parsing #{file}. Skipping."
  rescue RubyParser::SyntaxError, Racc::ParseError => e
    q = option[:quiet]
    if e.inspect =~ /<\%|%\>/ or ruby =~ /<\%|%\>/ then
      return if q
      warn "#{e.inspect} at #{e.backtrace.first(5).join(', ')}"
      warn "\n...stupid lemmings and their bad erb templates... skipping"
    else
      warn "ERROR: parsing ruby file #{file}" unless q
      unless option[:continue] then
        warn "ERROR! Aborting. You may want to run with --continue."
        raise e
      end
      return if q
      warn "%s: %s at:\n  %s" % [e.class, e.message.strip,
                                 e.backtrace.first(5).join("\n  ")]
    end
  end

  ##
  # Flog the given ruby source, optionally using file to provide paths for
  # methods. Does not handle timeouts or syntax errors. See #flog_ruby.

  def flog_ruby! ruby, file="-", timeout = 10
    @parser = (option[:parser] || RubyParser).new

    warn "** flogging #{file}" if option[:verbose]

    ast = @parser.process ruby, file, timeout

    return unless ast

    mass[file] = ast.mass
    process ast
  end

  ##
  # Adds name to the class stack, for the duration of the block

  def in_klass name
    if Sexp === name then
      name = case name.first
             when :colon2 then
               name = name.flatten
               name.delete :const
               name.delete :colon2
               name.join("::")
             when :colon3 then
               name.last.to_s
             else
               raise "unknown type #{name.inspect}"
             end
    end

    @class_stack.unshift name
    yield
    @class_stack.shift
  end

  ##
  # Adds name to the method stack, for the duration of the block

  def in_method(name, file, line)
    method_name = Regexp === name ? name.inspect : name.to_s
    @method_stack.unshift method_name
    @method_locations[signature] = "#{file}:#{line}"
    yield
    @method_stack.shift
  end

  ##
  # Creates a new Flog instance with +options+.

  def initialize option = {}
    super()
    @option              = option
    @sclass              = []
    @class_stack         = []
    @method_stack        = []
    @method_locations    = {}
    @mass                = {}
    @parser              = nil
    self.auto_shift_type = true
    self.reset
  end

  ##
  # Returns the first class in the list, or @@no_class if there are
  # none.

  def klass_name
    name = @class_stack.first

    if Sexp === name then
      raise "you shouldn't see me"
    elsif @class_stack.any?
      @class_stack.reverse.join("::").sub(/\([^\)]+\)$/, '')
    else
      @@no_class
    end
  end

  ##
  # Returns the first method in the list, or "#none" if there are
  # none.

  def method_name
    m = @method_stack.first || @@no_method
    m = "##{m}" unless m =~ /::/
    m
  end

  ##
  # Output the report up to a given max or report everything, if nil.

  def output_details io, max = nil
    io.puts

    each_by_score max do |class_method, score, call_list|
      return 0 if option[:methods] and class_method =~ /##{@@no_method}/

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
  # Calculates classes and methods scores.

  def calculate
    each_by_score threshold do |class_method, score, call_list|
      klass = class_method.split(/#|::/).first

      methods[klass] << [class_method, score]
      scores[klass]  += score
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

      methods[klass].each do |name, score|
        self.print_score io, name, score
      end
    end
  end

  ##
  # For the duration of the block the complexity factor is increased
  # by #bonus This allows the complexity of sub-expressions to be
  # influenced by the expressions in which they are found.  Yields 42
  # to the supplied block.

  def penalize_by bonus
    @multiplier += bonus
    yield
    @multiplier -= bonus
  end

  ##
  # Print out one formatted score.

  def print_score io, name, score
    location = @method_locations[name]
    if location then
      io.puts "%8.1f: %-32s %s" % [score, name, location]
    else
      io.puts "%8.1f: %s" % [score, name]
    end
  end

  ##
  # Process each element of #exp in turn.

  def process_until_empty exp
    process exp.shift until exp.empty?
  end

  ##
  # Final threshold that is used for report

  def threshold
    option[:all] ? nil : total * THRESHOLD
  end

  ##
  # Report results to #io, STDOUT by default.

  def report(io = $stdout)
    io.puts "%8.1f: %s" % [total, "flog total"]
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

  ##
  # Reset score data

  def reset
    @totals     = @total_score = nil
    @multiplier = 1.0
    @calls      = Hash.new { |h,k| h[k] = Hash.new 0 }
    @methods    = Hash.new { |h,k| h[k] = [] }
    @scores     = Hash.new 0
  end

  ##
  # Compute the distance formula for a given tally

  def score_method(tally)
    a, b, c = 0, 0, 0
    tally.each do |cat, score|
      case cat
      when :assignment then a += score
      when :branch     then b += score
      else                  c += score
      end
    end
    Math.sqrt(a*a + b*b + c*c)
  end

  ##
  # Returns the method signature for the current method.

  def signature
    "#{klass_name}#{method_name}"
  end

  ##
  # Calculates and returns the score (and total score on the side).

  def total # FIX: I hate this indirectness
    totals unless @total_score # calculates total_score as well

    @total_score
  end

  ##
  # Returns the maximum score for a single method. Used for FlogTask.

  def max_score
    max_method.last
  end

  ##
  # Returns the method/score pair of the maximum score.

  def max_method
    totals.max_by { |_, score| score }
  end

  ##
  # Return the total score and populates @totals.

  def totals
    unless @totals then
      @total_score = 0
      @totals = Hash.new(0)

      calls.each do |meth, tally|
        next if option[:methods] and meth =~ /##{@@no_method}$/
        score = score_method(tally)

        @totals[meth] = score
        @total_score += score
      end
    end

    @totals
  end

  ############################################################
  # Process Methods:

  # :stopdoc:
  def process_alias(exp)
    process exp.shift
    process exp.shift
    add_to_score :alias
    s()
  end

  def process_and(exp)
    add_to_score :branch
    penalize_by 0.1 do
      process exp.shift # lhs
      process exp.shift # rhs
    end
    s()
  end
  alias :process_or :process_and

  def process_attrasgn(exp)
    add_to_score :assignment
    process exp.shift # lhs
    exp.shift # name
    process_until_empty exp # rhs
    s()
  end

  def process_block(exp)
    penalize_by 0.1 do
      process_until_empty exp
    end
    s()
  end

  def process_block_pass(exp)
    arg = exp.shift

    add_to_score :block_pass

    case arg.first
    when :lvar, :dvar, :ivar, :cvar, :self, :const, :colon2, :nil then # f(&b)
      # do nothing
    when :lit, :call then                                              # f(&:b)
      add_to_score :to_proc_normal
    when :lasgn then                                                   # f(&l=b)
      add_to_score :to_proc_lasgn
    when :iter, :dsym, :dstr, *BRANCHING then                          # below
      # f(&proc { ... })
      # f(&"#{...}")
      # f(&:"#{...}")
      # f(&if ... then ... end") and all other branching forms
      add_to_score :to_proc_icky!
    else
      raise({:block_pass_even_ickier! => arg}.inspect)
    end

    process arg

    s()
  end

  def process_call(exp)
    penalize_by 0.2 do
      process exp.shift # recv
    end

    name = exp.shift

    penalize_by 0.2 do
      process_until_empty exp
    end

    add_to_score name, SCORES[name]

    s()
  end

  def process_case(exp)
    add_to_score :branch
    process exp.shift # recv
    penalize_by 0.1 do
      process_until_empty exp
    end
    s()
  end

  def process_class(exp)
    in_klass exp.shift do
      penalize_by 1.0 do
        process exp.shift # superclass expression
      end
      process_until_empty exp
    end
    s()
  end

  def process_dasgn_curr(exp) # FIX: remove
    add_to_score :assignment
    exp.shift # name
    process exp.shift # assigment, if any
    s()
  end
  alias :process_iasgn :process_dasgn_curr
  alias :process_lasgn :process_dasgn_curr

  def process_defn(exp)
    name = @sclass.empty? ? exp.shift : "::#{exp.shift}"
    in_method name, exp.file, exp.line do
      process_until_empty exp
    end
    s()
  end

  def process_defs(exp)
    process exp.shift # recv
    in_method "::#{exp.shift}", exp.file, exp.line do
      process_until_empty exp
    end
    s()
  end

  # TODO:  it's not clear to me whether this can be generated at all.
  def process_else(exp)
    add_to_score :branch
    penalize_by 0.1 do
      process_until_empty exp
    end
    s()
  end
  alias :process_rescue :process_else
  alias :process_when   :process_else

  def process_if(exp)
    add_to_score :branch
    process exp.shift # cond
    penalize_by 0.1 do
      process exp.shift # true
      process exp.shift # false
    end
    s()
  end

  def dsl_name? args
    return false unless args and not args.empty?

    first_arg = args.first
    first_arg = first_arg[1] if first_arg[0] == :hash

    [:lit, :str].include? first_arg[0] and first_arg[1]
  end

  def process_iter(exp)
    context = (self.context - [:class, :module, :scope])
    context = context.uniq.sort_by { |s| s.to_s }

    exp.delete 0 # { || ... } has 0 in arg slot

    if context == [:block, :iter] or context == [:iter] then
      recv = exp.first

      # DSL w/ names. eg task :name do ... end
      #   looks like s(:call, nil, :task, s(:lit, :name))
      #           or s(:call, nil, :task, s(:str, "name"))
      #           or s(:call, nil, :task, s(:hash, s(:lit, :name) ...))

      t, r, m, *a = recv

      if t == :call and r == nil and submsg = dsl_name?(a) then
        m = "#{m}(#{submsg})" if m and [String, Symbol].include?(submsg.class)
        in_klass m do                             # :task/namespace
          in_method submsg, exp.file, exp.line do # :name
            process_until_empty exp
          end
        end
        return s()
      end
    end

    add_to_score :branch

    process exp.shift # no penalty for LHS

    penalize_by 0.1 do
      process_until_empty exp
    end

    s()
  end

  def process_lit(exp)
    value = exp.shift
    case value
    when 0, -1 then
      # ignore those because they're used as array indicies instead of
      # first/last
    when Integer then
      add_to_score :lit_fixnum
    when Float, Symbol, Regexp, Range then
      # do nothing
    else
      raise value.inspect
    end
    s()
  end

  def process_masgn(exp)
    add_to_score :assignment

    exp.map! { |s| Sexp === s ? s : s(:lasgn, s) }

    process_until_empty exp
    s()
  end

  def process_module(exp)
    in_klass exp.shift do
      process_until_empty exp
    end
    s()
  end

  def process_sclass(exp)
    @sclass.push(true)
    penalize_by 0.5 do
      process exp.shift # recv
      process_until_empty exp
    end
    @sclass.pop

    add_to_score :sclass
    s()
  end

  def process_super(exp)
    add_to_score :super
    process_until_empty exp
    s()
  end

  def process_while(exp)
    add_to_score :branch
    penalize_by 0.1 do
      process exp.shift # cond
      process exp.shift # body
    end
    exp.shift # pre/post
    s()
  end
  alias :process_until :process_while

  def process_yield(exp)
    add_to_score :yield
    process_until_empty exp
    s()
  end
  # :startdoc:
end
