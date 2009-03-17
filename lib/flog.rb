require 'rubygems'
require 'parse_tree'
require 'sexp_processor'
require 'unified_ruby'

class Flog < SexpProcessor
  VERSION = '2.0.1'

  include UnifiedRuby

  THRESHOLD = 0.60
  SCORES = Hash.new 1
  BRANCHING = [ :and, :case, :else, :if, :or, :rescue, :until, :when, :while ]

  ##
  # various non-call constructs

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
    :to_proc_normal => 5,
    :yield          => 1,
  }

  ##
  # eval forms

  SCORES.merge!(:define_method => 5,
                :eval          => 5,
                :module_eval   => 5,
                :class_eval    => 5,
                :instance_eval => 5)

  ##
  # various "magic" usually used for "clever code"

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
  # calls I don't like and usually see being abused

  SCORES.merge!(:inject => 2)

  @@no_class  = :main
  @@no_method = :none

  attr_accessor :multiplier
  attr_reader :calls, :options, :class_stack, :method_stack

  def self.default_options
    {
      :quiet => true,
    }
  end

  def self.parse_options
    options = self.default_options
    op = OptionParser.new do |opts|
      opts.on("-a", "--all", "Display all flog results, not top 60%.") do |a|
        options[:all] = a
      end

      opts.on("-b", "--blame", "Include blame information for methods.") do |b|
        options[:blame] = b
      end

      opts.on("-c", "--continue", "Continue despite syntax errors.") do |c|
        options[:continue] = c
      end

      opts.on("-d", "--details", "Show method details.") do
        options[:details] = true
      end

      opts.on("-g", "--group", "Group and sort by class.") do
        options[:group] = true
      end

      opts.on("-h", "--help", "Show this message.") do
        puts opts
        exit
      end

      opts.on("-I path1,path2,path3", Array, "Ruby include paths to search.") do |i|
        options[:paths] = i.map { |l| l.to_s }
      end

      opts.on("-m", "--methods-only", "Skip code outside of methods.") do |m|
        options[:methods] = m
      end

      opts.on("-q", "--quiet", "Don't show method details. [default]")  do |v|
        options[:quiet] = v
      end

      opts.on("-s", "--score", "Display total score only.")  do |s|
        options[:score] = s
      end

      opts.on("-v", "--verbose", "Display progress during processing.")  do |v|
        options[:verbose] = v
      end
    end.parse!

    options
  end

  # TODO: rename options to option, you only deal with them one at a time...

  def add_to_score name, score = OTHER_SCORES[name]
    @calls["#{klass_name}##{method_name}"][name] += score * @multiplier
  end

  ##
  # Process each element of #exp in turn.

  def analyze_list exp
    process exp.shift until exp.empty?
  end

  def average
    return 0 if calls.size == 0
    total / calls.size
  end

  def collect_blame filename # TODO: huh?
  end

  def flog ruby, file
    collect_blame(file) if options[:blame]
    process_parse_tree(ruby, file)
  rescue SyntaxError => e
    if e.inspect =~ /<%|%>/ then
      warn e.inspect + " at " + e.backtrace.first(5).join(', ')
      warn "\n...stupid lemmings and their bad erb templates... skipping"
    else
      raise e unless options[:continue]
      warn file
      warn "#{e.inspect} at #{e.backtrace.first(5).join(', ')}"
    end
  end

  def flog_directory dir
    Dir["#{dir}/**/*.rb"].each do |file|
      flog_file(file)
    end
  end

  def flog_file file
    return flog_directory(file) if File.directory? file
    if file == '-'
      raise "Cannot provide blame information for code provided on input stream." if options[:blame]
      data = $stdin.read
    end
    data ||= File.read(file)
    warn "** flogging #{file}" if options[:verbose]
    flog(data, file)
  end

  ##
  # Process #files with flog, recursively descending directories.
  #--
  # There is no way to exclude directories at present (RCS, SCCS, .svn)
  #++

  def flog_files(*files)
    files.flatten.each do |file|
      flog_file(file)
    end
  end

  def in_klass name
    @class_stack.unshift name
    yield
    @class_stack.shift
  end

  ##
  # Adds name to the list of methods, for the duration of the block

  def in_method name
    @method_stack.unshift name
    yield
    @method_stack.shift
  end

  def increment_total_score_by amount
    raise "@total_score isn't even set yet... dumbass" unless @total_score
    @total_score += amount
  end

  def initialize options = {}
    super()
    @options = options
    @class_stack = []
    @method_stack = []
    self.auto_shift_type = true
    self.require_empty = false # HACK
    self.reset
  end

  ##
  # returns the first class in the list, or @@no_class if there are
  # none.

  def klass_name
    name = @class_stack.first || @@no_class
    if Sexp === name then
      name = case name.first
             when :colon2 then
               name = name.flatten
               name.delete :const
               name.delete :colon2
               name.join("::")
             when :colon3 then
               name.last
             else
               name
             end
    end
    name
  end

  ##
  # returns the first method in the list, or @@no_method if there are
  # none.

  def method_name
    @method_stack.first || @@no_method
  end

  def output_details(io, max = nil)
    my_totals = totals
    current = 0

    if options[:group] then
      scores = Hash.new 0
      methods = Hash.new { |h,k| h[k] = [] }

      calls.sort_by { |k,v| -my_totals[k] }.each do |class_method, call_list|
        klass = class_method.split(/#|::/).first
        score = totals[class_method]
        methods[klass] << [class_method, score]
        scores[klass] += score
        current += score
        break if max and current >= max
      end

      scores.sort_by { |_, n| -n }.each do |klass, total|
        io.puts
        io.puts "%8.1f: %s" % [total, "#{klass} total"]
        methods[klass].each do |name, score|
          io.puts "%8.1f: %s" % [score, name]
        end
      end
    else
      io.puts
      calls.sort_by { |k,v| -my_totals[k] }.each do |class_method, call_list|
        current += output_method_details(io, class_method, call_list)
        break if max and current >= max
      end
    end
  end

  def output_method_details(io, class_method, call_list)
    return 0 if options[:methods] and class_method =~ /##{@@no_method}/

    total = totals[class_method]
    io.puts "%8.1f: %s" % [total, class_method]

    call_list.sort_by { |k,v| -v }.each do |call, count|
      io.puts "  %6.1f: %s" % [count, call]
    end if options[:details]

    total
  end

  def output_summary(io)
    io.puts "%8.1f: %s" % [total, "flog total"]
    io.puts "%8.1f: %s" % [average, "flog/method average"]
  end

  def parse_tree
    @parse_tree ||= ParseTree.new(false)
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

  def process_parse_tree(ruby, file) # TODO: rename away from process
    sexp = parse_tree.parse_tree_for_string(ruby, file)
    process Sexp.from_array(sexp).first
  end

  def record_method_score(method, score)
    @totals ||= Hash.new(0)
    @totals[method] = score
  end

  ##
  # Report results to #io, STDOUT by default.

  def report(io = $stdout)
    output_summary(io)
    return if options[:score]

    if options[:all] then # TODO: fix - use option[:all] and THRESHOLD directly
      output_details(io)
    else
      output_details(io, total * THRESHOLD)
    end
  ensure
    self.reset
  end

  def reset
    @totals = @total_score = nil
    @multiplier = 1.0
    @calls = Hash.new { |h,k| h[k] = Hash.new 0 }
  end

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

  def summarize_method(meth, tally)
    return if options[:methods] and meth =~ /##{@@no_method}$/
    score = score_method(tally)
    record_method_score(meth, score)
    increment_total_score_by score
  end

  def total
    totals unless @total_score # calculates total_score as well

    @total_score
  end

  ##
  # Return the total score and populates @totals.

  def totals
    unless @totals then
      @total_score = 0
      @totals = Hash.new(0)
      calls.each do |meth, tally|
        summarize_method(meth, tally)
      end
    end
    @totals
  end

  ############################################################
  # Process Methods:

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
    process exp.shift # rhs
    s()
  end

  def process_attrset(exp)
    add_to_score :assignment
    raise exp.inspect
    s()
  end

  def process_block(exp)
    penalize_by 0.1 do
      analyze_list exp
    end
    s()
  end

  def process_block_pass(exp)
    arg = exp.shift

    add_to_score :block_pass

    case arg.first
    when :lvar, :dvar, :ivar, :cvar, :self, :const, :nil then
      # do nothing
    when :lit, :call then
      add_to_score :to_proc_normal
    when :iter, :dsym, :dstr, *BRANCHING then
      add_to_score :to_proc_icky!
    else
      raise({:block_pass_even_ickier! => [arg, call]}.inspect)
    end

    process arg

    s()
  end

  def process_call(exp)
    penalize_by 0.2 do
      recv = process exp.shift
    end
    name = exp.shift
    penalize_by 0.2 do
      args = process exp.shift
    end

    add_to_score name, SCORES[name]

    s()
  end

  def process_case(exp)
    add_to_score :branch
    process exp.shift # recv
    penalize_by 0.1 do
      analyze_list exp
    end
    s()
  end

  def process_class(exp)
    in_klass exp.shift do
      penalize_by 1.0 do
        supr = process exp.shift
      end
      analyze_list exp
    end
    s()
  end

  def process_dasgn_curr(exp)
    add_to_score :assignment
    exp.shift # name
    process exp.shift # assigment, if any
    s()
  end
  alias :process_iasgn :process_dasgn_curr
  alias :process_lasgn :process_dasgn_curr

  def process_defn(exp)
    in_method exp.shift do
      analyze_list exp
    end
    s()
  end

  def process_defs(exp)
    process exp.shift
    in_method exp.shift do
      analyze_list exp
    end
    s()
  end

  # TODO:  it's not clear to me whether this can be generated at all.
  def process_else(exp)
    add_to_score :branch
    penalize_by 0.1 do
      analyze_list exp
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
    if context.uniq.sort_by {|s|s.to_s} == [:block, :iter] then
      recv = exp.first
      if (recv[0] == :call and recv[1] == nil and recv.arglist[1] and
          [:lit, :str].include? recv.arglist[1][0]) then
        msg = recv[2]
        submsg = recv.arglist[1][1]
        in_method submsg do
          in_klass msg do
            analyze_list exp
          end
        end
        return s()
      end
    end

    add_to_score :branch

    exp.pop if exp.last == 0
    process exp.shift # no penalty for LHS

    penalize_by 0.1 do
      analyze_list exp
    end

    s()
  end

  def process_lit(exp)
    value = exp.shift
    case value
    when 0, -1 then
      # ignore those because they're used as array indicies instead of first/last
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
    analyze_list exp
    s()
  end

  def process_module(exp)
    in_klass exp.shift do
      analyze_list exp
    end
    s()
  end

  def process_sclass(exp)
    penalize_by 0.5 do
      recv = process exp.shift
      analyze_list exp
    end

    add_to_score :sclass
    s()
  end

  def process_super(exp)
    add_to_score :super
    analyze_list exp
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
    analyze_list exp
    s()
  end
end
