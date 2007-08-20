require 'rubygems'
require 'parse_tree'
require 'sexp_processor'
require 'unified_ruby'

$a ||= false
$s ||= false
$v ||= false

class Flog < SexpProcessor
  VERSION = '1.1.0'

  include UnifiedRuby

  THRESHOLD = $a ? 1.0 : 0.60
  SCORES = Hash.new(1)
  BRANCHING = [ :and, :case, :else, :if, :or, :rescue, :until, :when, :while ]

  # various non-call constructs
  OTHER_SCORES = {
    :alias => 2,
    :assignment => 1,
    :block => 1,
    :branch => 1,
    :lit_fixnum => 0.25,
    :sclass => 5,
    :super => 1,
    :to_proc_icky! => 10,
    :to_proc_normal => 5,
    :yield => 1,
  }

  # eval forms
  SCORES.merge!(:define_method => 5,
                :eval => 5,
                :module_eval => 5,
                :class_eval => 5,
                :instance_eval => 5)

  # various "magic" usually used for "clever code"
  SCORES.merge!(:alias_method => 2,
                :extend => 2,
                :include => 2,
                :instance_method => 2,
                :instance_methods => 2,
                :method_added => 2,
                :method_defined? => 2,
                :method_removed => 2,
                :method_undefined => 2,
                :private_class_method => 2,
                :private_instance_methods => 2,
                :private_method_defined? => 2,
                :protected_instance_methods => 2,
                :protected_method_defined? => 2,
                :public_class_method => 2,
                :public_instance_methods => 2,
                :public_method_defined? => 2,
                :remove_method => 2,
                :send => 3,
                :undef_method => 2)

  # calls I don't like and usually see being abused
  SCORES.merge!(:inject => 2)

  @@no_class = :main
  @@no_method = :none

  attr_reader :calls

  def initialize
    super
    @pt = ParseTree.new(false)
    @klasses = []
    @methods = []
    self.auto_shift_type = true
    self.require_empty = false # HACK
    self.reset
  end

  def add_to_score(name, score)
    @calls["#{self.klass_name}##{self.method_name}"][name] += score * @multiplier
  end

  def bad_dog! bonus
    @multiplier += bonus
    yield 42
    @multiplier -= bonus
  end

  def bleed exp
    process exp.shift until exp.empty?
  end

  def flog_files *files
    files.flatten.each do |file|
      if File.directory? file then
        flog_files Dir["#{file}/**/*.rb"]
      else
        warn "** flogging #{file}" if $v
        ruby = file == "-" ? $stdin.read : File.read(file)
        begin
          sexp = @pt.parse_tree_for_string(ruby, file)
          process Sexp.from_array(sexp).first
        rescue SyntaxError => e
          if e.inspect =~ /<%|%>/ then
            warn e.inspect + " at " + e.backtrace.first(5).join(', ')
            warn "...stupid lemmings and their bad erb templates... skipping"
          else
            raise e
          end
        end
      end
    end
  end

  def klass name
    @klasses.unshift name
    yield
    @klasses.shift
  end

  def klass_name
    @klasses.first || @@no_class
  end

  def method name
    @methods.unshift name
    yield
    @methods.shift
  end

  def method_name
    @methods.first || @@no_method
  end

  def report io = $stdout
    current = 0
    total_score = self.total
    max = total_score * THRESHOLD
    totals = self.totals

    if $s then
      io.puts total_score
      exit 0
    end

    io.puts "Total score = #{total_score}"
    io.puts

    @calls.sort_by { |k,v| -totals[k] }.each do |klass_method, calls|
      total = totals[klass_method]
      io.puts "%s: (%.1f)" % [klass_method, total]
      calls.sort_by { |k,v| -v }.each do |call, count|
        io.puts "  %6.1f: %s" % [count, call]
      end

      current += total
      break if current >= max
    end
  ensure
    self.reset
  end

  def reset
    @totals = @total_score = nil
    @multiplier = 1.0
    @calls = Hash.new { |h,k| h[k] = Hash.new 0 }
  end

  def total
    self.totals unless @total_score # calculates total_score as well

    @total_score
  end

  def totals
    unless @totals then
      @total_score = 0
      @totals = Hash.new(0)
      self.calls.each do |meth, tally|
        a, b, c = 0, 0, 0
        tally.each do |cat, score|
          case cat
          when :assignment then a += score
          when :branch     then b += score
          else                  c += score
          end
        end
        score = Math.sqrt(a*a + b*b + c*c)
        @totals[meth] = score
        @total_score += score
      end
    end
    @totals
  end

  ############################################################
  # Process Methods:

  def process_alias(exp)
    process exp.shift
    process exp.shift
    add_to_score :alias, OTHER_SCORES[:alias]
    s()
  end

  def process_and(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      process exp.shift # lhs
      process exp.shift # rhs
    end
    s()
  end

  def process_attrasgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    process exp.shift # lhs
    exp.shift # name
    process exp.shift # rhs
    s()
  end

  def process_attrset(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    raise exp.inspect
    s()
  end

  def process_block(exp)
    bad_dog! 0.1 do
      bleed exp
    end
    s()
  end

  # [:block_pass, [:lit, :blah], [:fcall, :foo]]
  def process_block_pass(exp)
    arg = exp.shift
    call = exp.shift

    add_to_score :block_pass, OTHER_SCORES[:block]

    case arg.first
    when :lvar, :dvar, :ivar, :cvar, :self, :const, :nil then
      # do nothing
    when :lit, :call then
      add_to_score :to_proc_normal, OTHER_SCORES[:to_proc_normal]
    when :iter, *BRANCHING then
      add_to_score :to_proc_icky!, OTHER_SCORES[:to_proc_icky!]
    else
      raise({:block_pass => [arg, call]}.inspect)
    end

    process arg
    process call

    s()
  end

  def process_call(exp)
    bad_dog! 0.2 do
      recv = process exp.shift
    end
    name = exp.shift
    bad_dog! 0.2 do
      args = process exp.shift
    end

    score = SCORES[name]
    add_to_score name, score

    s()
  end

  def process_case(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # recv
    bad_dog! 0.1 do
      bleed exp
    end
    s()
  end

  def process_class(exp)
    self.klass exp.shift do
      bad_dog! 1.0 do
        supr = process exp.shift
      end
      bleed exp
    end
    s()
  end

  def process_dasgn_curr(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    exp.shift # name
    process exp.shift # assigment, if any
    s()
  end

  def process_defn(exp)
    self.method exp.shift do
      bleed exp
    end
    s()
  end

  def process_defs(exp)
    process exp.shift
    self.method exp.shift do
      bleed exp
    end
    s()
  end

  def process_else(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      bleed exp
    end
    s()
  end

  def process_iasgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    exp.shift # name
    process exp.shift # rhs
    s()
  end

  def process_if(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # cond
    bad_dog! 0.1 do
      process exp.shift # true
      process exp.shift # false
    end
    s()
  end

  def process_iter(exp)
    context = (self.context - [:class, :module, :scope])
    if context.uniq.sort_by {|s|s.to_s} == [:block, :iter] then
      recv = exp.first
      if recv[0] == :call and recv[1] == nil and recv.arglist[1] and [:lit, :str].include? recv.arglist[1][0] then
        msg = recv[2]
        submsg = recv.arglist[1][1]
        self.method submsg do
          self.klass msg do
            bleed exp
          end
        end
        return s()
      end
    end

    add_to_score :branch, OTHER_SCORES[:branch]

    process exp.shift # no penalty for LHS

    bad_dog! 0.1 do
      bleed exp
    end

    s()
  end

  def process_lasgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    exp.shift # name
    process exp.shift # rhs
    s()
  end

  def process_lit(exp)
    value = exp.shift
    case value
    when 0, -1 then
      # ignore those because they're used as array indicies instead of first/last
    when Integer then
      add_to_score :lit_fixnum, OTHER_SCORES[:lit_fixnum]
    when Float, Symbol, Regexp, Range then
      # do nothing
    else
      raise value.inspect
    end
    s()
  end

  def process_masgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    process exp.shift # lhs
    process exp.shift # rhs
    s()
  end

  def process_module(exp)
    self.klass exp.shift do
      bleed exp
    end
    s()
  end

  def process_or(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      process exp.shift # lhs
      process exp.shift # rhs
    end
    s()
  end

  def process_rescue(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      bleed exp
    end
    s()
  end

  def process_sclass(exp)
    bad_dog! 0.5 do
      recv = process exp.shift
      bleed exp
    end

    add_to_score :sclass, OTHER_SCORES[:sclass]
    s()
  end

  def process_super(exp)
    add_to_score :super, OTHER_SCORES[:super]
    bleed exp
    s()
  end

  def process_until(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      process exp.shift # cond
      process exp.shift # body
    end
    exp.shift # pre/post
    s()
  end

  def process_when(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      bleed exp
    end
    s()
  end

  def process_while(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bad_dog! 0.1 do
      process exp.shift # cond
      process exp.shift # body
    end
    exp.shift # pre/post
    s()
  end

  def process_yield(exp)
    add_to_score :yield, OTHER_SCORES[:yield]
    bleed exp
    s()
  end
end
