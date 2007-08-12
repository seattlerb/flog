require 'rubygems'
require 'parse_tree'
require 'sexp_processor'
require 'unified_ruby'

if defined? $I and String === $I then
  $I.split(/:/).each do |dir|
    $: << dir
  end
end

class Flog < SexpProcessor
  VERSION = '1.1.0'

  include UnifiedRuby

  THRESHOLD = $a ? 1.0 : 0.60

  SCORES = Hash.new(1)

  # various non-call constructs
  OTHER_SCORES = {
    :alias => 2,
    :assignment => 1,
    :branch => 1,
    :lit_fixnum => 0.25,
    :sclass => 5,
    :super => 1,
    :to_proc_normal => 5,
    :to_proc_wtf? => 10,
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

  @@no_class = :none
  @@no_method = :none

  def initialize
    super
    @pt = ParseTree.new(false)
    @klass_name, @method_name = @@no_class, @@no_method
    self.auto_shift_type = true
    self.require_empty = false # HACK
    @totals = Hash.new 0
    @multiplier = 1.0

    @calls = Hash.new { |h,k| h[k] = Hash.new 0 }
  end

  def process_files *files
    files.flatten.each do |file|
      next unless File.file? file or file == "-"
      ruby = file == "-" ? $stdin.read : File.read(file)
      sexp = @pt.parse_tree_for_string(ruby, file)
      process Sexp.from_array(sexp).first
    end
  end

  def report
    total_score = 0
    @totals.values.each do |n|
      total_score += n
    end

    max = total_score * THRESHOLD
    current = 0

    puts "Total score = #{total_score}"
    puts

    @calls.sort_by { |k,v| -@totals[k] }.each do |klass_method, calls|
      total = @totals[klass_method]
      puts "%s: (%.1f)" % [klass_method, total]
      calls.sort_by { |k,v| -v }.each do |call, count|
        puts "  %6.1f: %s" % [count, call]
      end

      current += total
      break if current >= max
    end
  rescue
    # do nothing
  end

  def add_to_score(name, score)
#     case name
#     when :assignment then
#     when :branch then
#     else
      @totals["#{@klass_name}##{@method_name}"] += score * @multiplier
      @calls["#{@klass_name}##{@method_name}"][name] += score * @multiplier
#     end
  end

  def bad_dog! bonus
    @multiplier += bonus
    yield 42
    @multiplier -= bonus
  end

  def bleed exp
    process exp.shift until exp.empty?
  end

  ############################################################
  # Process Methods:

  # when :attrasgn, :attrset, :dasgn_curr, :iasgn, :lasgn, :masgn then
  #   a += 1
  # when :and, :case, :else, :if, :iter, :or, :rescue, :until, :when, :while then
  #   b += 1
  # when :call, :fcall, :super, :vcall, :yield then
  #   c += 1

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

  def process_dasgn_curr(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    exp.shift # name
    process exp.shift # assigment, if any
    s()
  end

  def process_iasgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    exp.shift # name
    process exp.shift # rhs
    s()
  end

  def process_lasgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    exp.shift # name
    process exp.shift # rhs
    s()
  end

  def process_masgn(exp)
    add_to_score :assignment, OTHER_SCORES[:assignment]
    process exp.shift # lhs
    process exp.shift # rhs
    s()
  end

  def process_and(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # lhs
    process exp.shift # rhs
    s()
  end

  def process_case(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # recv
    bleed exp
    s()
  end

  def process_else(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bleed exp
    s()
  end

  def process_if(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # cond
    process exp.shift # true
    process exp.shift # false
    s()
  end

  def process_or(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # lhs
    process exp.shift # rhs
    s()
  end

  def process_rescue(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bleed exp
    s()
  end

  def process_until(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # cond
    process exp.shift # body
    exp.shift # pre/post
    s()
  end

  def process_when(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    bleed exp
    s()
  end

  def process_while(exp)
    add_to_score :branch, OTHER_SCORES[:branch]
    process exp.shift # cond
    process exp.shift # body
    exp.shift # pre/post
    s()
  end

  def process_super(exp)
    add_to_score :super, OTHER_SCORES[:super]
    bleed exp
    s()
  end

  def process_yield(exp)
    add_to_score :yield, OTHER_SCORES[:yield]
    bleed exp
    s()
  end

  # klasses.each do |klass|
  #   klass.shift # :class
  #   klassname = klass.shift
  #   klass.shift # superclass
  #   methods = klass

  #   methods.each do |defn|
  #     a=b=c=0
  #     defn.shift
  #     methodname = defn.shift
  #     tokens = defn.structure.flatten
  #     tokens.each do |token|
  #       case token
  #       end
  #     end
  #     key = ["#{klassname}.#{methodname}", a, b, c]
  #     val = Math.sqrt(a*a+b*b+c*c)
  #     score[key] = val
  #   end
  # end

  ############################################################

  def process_alias(exp)
    process exp.shift
    process exp.shift
    add_to_score :alias, OTHER_SCORES[:alias]
    s()
  end

  def process_block(exp)
    bad_dog! 0.1 do
      bleed exp
    end
    s()
  end

  def process_iter(exp)
    if self.context.uniq.sort_by {|s|s.to_s} == [:block, :iter] then
      recv = exp.first

      if recv[0] == :call and recv[1] == nil and recv.arglist[1][0] == :lit then
        msg = recv[2]
        submsg = recv.arglist[1][1]
        @klass_name, @method_name = msg, submsg
        bleed exp
        @klass_name, @method_name = @@no_class, @@no_method
        return s()
      end
    else
      puts self.context.inspect
    end

    add_to_score :branch, OTHER_SCORES[:branch]

    process exp.shift # no penalty for LHS

    bad_dog! 0.1 do
      bleed exp
    end

    s()
  end

  # [:block_pass, [:lit, :blah], [:fcall, :foo]]
  def process_block_pass(exp)
    arg = exp.shift
    call = exp.shift

    case arg.first
    when :iter then
      add_to_score :to_proc_iter_wtf?, OTHER_SCORES[:to_proc_wtf?]
    when :lit, :call, :iter then
      add_to_score :to_proc_normal, OTHER_SCORES[:to_proc_normal]
    when :lvar, :dvar, :ivar, :nil then
      # do nothing
    else
      raise({:block_pass => [call, arg]}.inspect)
    end

    call = process call
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

  def process_class(exp)
    @klass_name = exp.shift
    bad_dog! 1.0 do
      supr = process exp.shift
    end
    bleed exp
    @klass_name = @@no_class
    s()
  end

  def process_defn(exp)
    @method_name = exp.shift
    bleed exp
    @method_name = @@no_method
    s()
  end

  def process_defs(exp)
    process exp.shift
    @method_name = exp.shift
    bleed exp
    @method_name = @@no_method
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

  def process_module(exp)
    @klass_name = exp.shift
    bleed exp
    @klass_name = @@no_class
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
end

