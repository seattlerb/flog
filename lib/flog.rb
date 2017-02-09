require "sexp_processor"
require "ruby_parser"
require "timeout"

class File
  RUBY19 = "<3".respond_to? :encoding unless defined? RUBY19 # :nodoc:

  class << self
    alias :binread :read unless RUBY19
  end
end

class Flog < MethodBasedSexpProcessor
  VERSION = "4.6.1" # :nodoc:

  ##
  # Cut off point where the report should stop unless --all given.

  DEFAULT_THRESHOLD = 0.60

  THRESHOLD = DEFAULT_THRESHOLD # :nodoc:

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
    :to_proc_normal => case RUBY_VERSION
                       when /^1\.8\.7/ then
                         2
                       when /^1\.9/ then
                         1.5
                       when /^2\./ then
                         1
                       else
                         5
                       end,
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

  # :stopdoc:
  attr_accessor :multiplier
  attr_reader :calls, :option, :mass
  attr_reader :method_scores, :scores
  attr_reader :total_score, :totals
  attr_writer :threshold

  # :startdoc:

  ##
  # Add a score to the tally. Score can be predetermined or looked up
  # automatically. Uses multiplier for additional spankings.
  # Spankings!

  def add_to_score name, score = OTHER_SCORES[name]
    return if option[:methods] and method_stack.empty?
    @calls[signature][name] += score * @multiplier
  end

  ##
  # really?

  def average
    return 0 if calls.size == 0
    total_score / calls.size
  end

  ##
  # Calculates classes and methods scores.

  def calculate
    each_by_score threshold do |class_method, score, call_list|
      klass = class_method.scan(/.+(?=#|::)/).first

      method_scores[klass] << [class_method, score]
      scores[klass] += score
    end
  end

  ##
  # Returns true if the form looks like a "DSL" construct.
  #
  #   task :blah do ... end
  #   => s(:iter, s(:call, nil, :task, s(:lit, :blah)), ...)

  def dsl_name? args
    return false unless args and not args.empty?

    first_arg = args.first
    first_arg = first_arg[1] if first_arg[0] == :hash

    [:lit, :str].include? first_arg[0] and first_arg[1]
  end

  ##
  # Iterate over the calls sorted (descending) by score.

  def each_by_score max = nil
    current = 0

    calls.sort_by { |k,v| -totals[k] }.each do |class_method, call_list|
      score = totals[class_method]

      yield class_method, score, call_list

      current += score
      break if max and current >= max
    end
  end

  ##
  # Flog the given files. Deals with "-", and syntax errors.
  #
  # Not as smart as FlogCLI's #flog method as it doesn't traverse
  # dirs. Use PathExpander to expand dirs into files.

  def flog(*files)
    files.each do |file|
      next unless file == '-' or File.readable? file

      ruby = file == '-' ? $stdin.read : File.binread(file)

      flog_ruby ruby, file
    end

    calculate_total_scores
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
  # Creates a new Flog instance with +options+.

  def initialize option = {}
    super()
    @option              = option
    @mass                = {}
    @parser              = nil
    @threshold           = option[:threshold] || DEFAULT_THRESHOLD
    self.auto_shift_type = true
    self.reset
  end

  ##
  # Returns the method/score pair of the maximum score.

  def max_method
    totals.max_by { |_, score| score }
  end

  ##
  # Returns the maximum score for a single method. Used for FlogTask.

  def max_score
    max_method.last
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
  # Reset score data

  def reset
    @totals           = @total_score = nil
    @multiplier       = 1.0
    @calls            = Hash.new { |h,k| h[k] = Hash.new 0 }
    @method_scores    = Hash.new { |h,k| h[k] = [] }
    @scores           = Hash.new 0
    method_locations.clear
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
  # Final threshold that is used for report

  def threshold
    option[:all] ? nil : total_score * @threshold
  end

  ##
  # Calculates the total score and populates @totals.

  def calculate_total_scores
    return if @totals

    @total_score = 0
    @totals = Hash.new(0)

    calls.each do |meth, tally|
      score = score_method(tally)

      @totals[meth] = score
      @total_score += score
    end
  end

  def no_method # :nodoc:
    @@no_method
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
    super do
      penalize_by 1.0 do
        process exp.shift # superclass expression
      end
      process_until_empty exp
    end
  end

  def process_dasgn_curr(exp) # FIX: remove
    add_to_score :assignment
    exp.shift # name
    process exp.shift # assigment, if any
    s()
  end
  alias :process_iasgn :process_dasgn_curr
  alias :process_lasgn :process_dasgn_curr

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
          in_method submsg, exp.file, exp.line, exp.line_max do # :name
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

  Rational = Integer unless defined? Rational # 1.8 / 1.9

  def process_lit(exp)
    value = exp.shift
    case value
    when 0, -1 then
      # ignore those because they're used as array indicies instead of
      # first/last
    when Integer, Rational then
      add_to_score :lit_fixnum
    when Float, Symbol, Regexp, Range then
      # do nothing
    else
      raise "Unhandled lit: #{value.inspect}:#{value.class}"
    end
    s()
  end

  def process_masgn(exp)
    add_to_score :assignment

    exp.map! { |s| Sexp === s ? s : s(:lasgn, s) }

    process_until_empty exp
    s()
  end

  def process_sclass(exp)
    super do
      penalize_by 0.5 do
        process exp.shift # recv
        process_until_empty exp
      end
    end

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
