require 'minitest/autorun'
require 'flog'

class TestFlog < MiniTest::Unit::TestCase
  def setup
    @flog = Flog.new
  end

  def test_add_to_score
    assert_empty @flog.calls
    @flog.class_stack  << "Base" << "MyKlass"
    @flog.method_stack << "mymethod"
    @flog.add_to_score "blah", 42

    expected = {"MyKlass::Base#mymethod" => {"blah" => 42.0}}
    assert_equal expected, @flog.calls

    @flog.add_to_score "blah", 2

    expected["MyKlass::Base#mymethod"]["blah"] = 44.0
    assert_equal expected, @flog.calls
  end

  def test_average
    test_process_and

    assert_equal 1.0, @flog.average
  end

  def test_cls_expand_dirs_to_files
    expected = %w(lib/flog.rb lib/flog_task.rb lib/gauntlet_flog.rb)
    assert_equal expected, Flog.expand_dirs_to_files('lib')
    expected = %w(Rakefile)
    assert_equal expected, Flog.expand_dirs_to_files('Rakefile')
  end

  def test_cls_parse_options
    # defaults
    opts = Flog.parse_options
    assert_equal true,  opts[:quiet]
    assert_equal false, opts[:continue]

    {
      "-a"             => :all,
      "--all"          => :all,
      "-b"             => :blame,
      "--blame"        => :blame,
      "-c"             => :continue,
      "--continue"     => :continue,
      "-d"             => :details,
      "--details"      => :details,
      "-g"             => :group,
      "--group"        => :group,
      "-m"             => :methods,
      "--methods-only" => :methods,
      "-q"             => :quiet,
      "--quiet"        => :quiet,
      "-s"             => :score,
      "--score"        => :score,
      "-v"             => :verbose,
      "--verbose"      => :verbose,
    }.each do |key, val|
      assert_equal true, Flog.parse_options(key)[val]
    end
  end

  def test_cls_parse_options_path
    old_path = $:.dup
    Flog.parse_options("-Ia,b,c")
    assert_equal old_path + %w(a b c), $:

    Flog.parse_options(["-I", "d,e,f"])
    assert_equal old_path + %w(a b c d e f), $:

    Flog.parse_options(["-I", "g", "-Ih"])
    assert_equal old_path + %w(a b c d e f g h), $:
  ensure
    $:.replace old_path
  end

  def test_cls_parse_options_help
    def Flog.exit
      raise "happy"
    end

    ex = nil
    o, e = capture_io do
      ex = assert_raises RuntimeError do
        Flog.parse_options "-h"
      end
    end

    assert_equal "happy", ex.message
    assert_match(/methods-only/, o)
    assert_equal "", e
  end

  def test_flog
    old_stdin = $stdin
    $stdin = StringIO.new "2 + 3"
    $stdin.rewind

    @flog.flog "-"

    exp = { "main#none" => { :+ => 1.0, :lit_fixnum => 0.6 } }
    assert_equal exp, @flog.calls

    assert_equal 1.6, @flog.total unless @flog.option[:methods]
    assert_equal 4, @flog.mass["-"] # HACK: 3 is for an unpublished sexp fmt
  ensure
    $stdin = old_stdin
  end

  def test_flog_erb
    old_stdin = $stdin
    $stdin = StringIO.new "2 + <%= blah %>"
    $stdin.rewind

    o, e = capture_io do
      @flog.flog "-"
    end

    assert_equal "", o
    assert_match(/stupid lemmings/, e)
  ensure
    $stdin = old_stdin
  end

  def test_in_klass
    assert_empty @flog.class_stack

    @flog.in_klass "xxx::yyy" do
      assert_equal ["xxx::yyy"], @flog.class_stack
    end

    assert_empty @flog.class_stack
  end

  def test_in_method
    assert_empty @flog.method_stack

    @flog.in_method "xxx", "file.rb", 42 do
      assert_equal ["xxx"], @flog.method_stack
    end

    assert_empty @flog.method_stack

    expected = {"main#xxx" => "file.rb:42"}
    assert_equal expected, @flog.method_locations
  end

  def test_klass_name
    assert_equal :main, @flog.klass_name

    @flog.class_stack << "whatevs" << "flog"
    assert_equal "flog::whatevs", @flog.klass_name
  end

  def test_klass_name_sexp
    @flog.in_klass s(:colon2, s(:const, :X), :Y) do
      assert_equal "X::Y", @flog.klass_name
    end

    @flog.in_klass s(:colon3, :Y) do
      assert_equal "Y", @flog.klass_name
    end
  end

  def test_method_name
    assert_equal "#none", @flog.method_name

    @flog.method_stack << "whatevs"
    assert_equal "#whatevs", @flog.method_name
  end

  def test_method_name_cls
    assert_equal "#none", @flog.method_name

    @flog.method_stack << "::whatevs"
    assert_equal "::whatevs", @flog.method_name
  end

  def test_output_details
    @flog.option[:all] = true
    test_flog

    @flog.totals["main#something"] = 42.0

    o = StringIO.new
    @flog.output_details o

    expected = "\n     1.6: main#none\n"

    assert_equal expected, o.string
    assert_equal 1.6, @flog.totals["main#none"]
  end

  def test_output_details_grouped
    test_flog

    o = StringIO.new
    @flog.output_details_grouped o

    expected = "\n     1.6: main total\n     1.6: main#none\n"

    assert_equal expected, o.string
  end

  def test_output_details_methods
    @flog.option[:methods] = true

    test_flog

    @flog.totals["main#something"] = 42.0 # TODO: no sense... why no output?

    o = StringIO.new
    @flog.output_details o

    # HACK assert_equal "", o.string
    assert_equal 0, @flog.totals["main#none"]
  end

  def test_output_details_detailed
    @flog.option[:details] = true

    test_flog

    @flog.totals["main#something"] = 42.0

    o = StringIO.new
    @flog.output_details o, nil

    expected = "\n     1.6: main#none
     1.0:   +
     0.6:   lit_fixnum

"

    assert_equal expected, o.string
    assert_equal 1.6, @flog.totals["main#none"]
  end

  # def test_process_until_empty
  #   flunk "no"
  # end

  def test_penalize_by
    assert_equal 1, @flog.multiplier
    @flog.penalize_by 2 do
      assert_equal 3, @flog.multiplier
    end
    assert_equal 1, @flog.multiplier
  end

  def test_process_alias
    sexp = s(:alias, s(:lit, :a), s(:lit, :b))

    util_process sexp, 2.0, :alias => 2.0
  end

  def test_process_and
    sexp = s(:and, s(:lit, :a), s(:lit, :b))

    util_process sexp, 1.0, :branch => 1.0
  end

  def test_process_attrasgn
    sexp = s(:attrasgn,
             s(:call, nil, :a, s(:arglist)),
             :[]=,
             s(:arglist,
               s(:splat,
                 s(:call, nil, :b, s(:arglist))),
               s(:call, nil, :c, s(:arglist))))

    util_process(sexp, 3.162,
                 :c => 1.0, :b => 1.0, :a => 1.0, :assignment => 1.0)
  end

  # def test_process_attrset
  #   sexp = s(:attrset, :@writer)
  #
  #   util_process(sexp, 3.162,
  #                :c => 1.0, :b => 1.0, :a => 1.0, :assignment => 1.0)
  #
  #   flunk "Not yet"
  # end

  def test_process_block
    sexp = s(:block, s(:and, s(:lit, :a), s(:lit, :b)))

    util_process sexp, 1.1, :branch => 1.1 # 10% penalty over process_and
  end

  def test_process_block_pass
    sexp = s(:call, nil, :a,
             s(:arglist,
               s(:block_pass,
                 s(:call, nil, :b, s(:arglist)))))

    util_process(sexp, 9.4,
                 :a              => 1.0,
                 :block_pass     => 1.2,
                 :b              => 1.2,
                 :to_proc_normal => 6.0)
  end

  def test_process_block_pass_colon2
    sexp = s(:call, nil, :a,
             s(:arglist,
               s(:block_pass,
                 s(:colon2, s(:const, :A), :B))))

    util_process(sexp, 2.2,
                 :a              => 1.0,
                 :block_pass     => 1.2)
  end

  def test_process_block_pass_iter
    sexp = s(:block_pass,
             s(:iter, s(:call, nil, :lambda, s(:arglist)), nil, s(:lit, 1)))

    util_process(sexp, 12.316,
                 :lit_fixnum    =>  0.275,
                 :block_pass    =>  1.0,
                 :lambda        =>  1.0,
                 :branch        =>  1.0,
                 :to_proc_icky! => 10.0)
  end

  def test_process_block_pass_lasgn
    sexp = s(:block_pass,
             s(:lasgn,
               :b,
               s(:iter, s(:call, nil, :lambda, s(:arglist)), nil, s(:lit, 1))))

    util_process(sexp, 17.333,
                 :lit_fixnum    =>  0.275,
                 :block_pass    =>  1.0,
                 :lambda        =>  1.0,
                 :assignment    =>  1.0,
                 :branch        =>  1.0,
                 :to_proc_lasgn => 15.0)
  end

  def test_process_call
    sexp = s(:call, nil, :a, s(:arglist))
    util_process sexp, 1.0, :a => 1.0
  end

  def test_process_case
    case :a
    when :a
      42
    end


    sexp = s(:case,
             s(:lit, :a),
             s(:when, s(:array, s(:lit, :a)), s(:nil)),
             nil)

    util_process sexp, 2.1, :branch => 2.1
  end

  def test_process_class
    @klass = "X::Y"

    sexp = s(:class,
             s(:colon2, s(:const, :X), :Y), nil,
             s(:scope, s(:lit, 42)))

    util_process sexp, 0.25, :lit_fixnum => 0.25
  end

  # TODO:
  # 392:  alias :process_or :process_and
  # 475:  alias :process_iasgn :process_dasgn_curr
  # 476:  alias :process_lasgn :process_dasgn_curr
  # 501:  alias :process_rescue :process_else
  # 502:  alias :process_when   :process_else
  # 597:  alias :process_until :process_while


  # def test_process_dasgn_curr
  #   flunk "Not yet"
  # end

  def test_process_defn
    @meth = "#x"

    sexp = s(:defn, :x,
             s(:args, :y),
             s(:scope,
               s(:block,
                 s(:lit, 42))))

    util_process sexp, 0.275, :lit_fixnum => 0.275
  end

  def test_process_defs
    @meth = "::x" # HACK, I don't like this

    sexp = s(:defs, s(:self), :x,
             s(:args, :y),
             s(:scope,
               s(:block,
                 s(:lit, 42))))

    util_process sexp, 0.275, :lit_fixnum => 0.275
  end

  # FIX: huh? over-refactored?
  # def test_process_else
  #   flunk "Not yet"
  # end

  def test_process_if
    sexp = s(:if,
             s(:call, nil, :b, s(:arglist)), # outside block, not penalized
             s(:call, nil, :a, s(:arglist)), nil)

    util_process sexp, 2.326, :branch => 1.0, :b => 1.0, :a => 1.1
  end

  def test_process_iter
    sexp = s(:iter,
             s(:call, nil, :loop, s(:arglist)), nil,
             s(:if, s(:true), s(:break), nil))

    util_process sexp, 2.326, :loop => 1.0, :branch => 2.1
  end

  def test_process_iter_dsl
    # task :blah do
    #   something
    # end

    sexp = s(:iter,
             s(:call, nil, :task, s(:arglist, s(:lit, :blah))),
             nil,
             s(:call, nil, :something, s(:arglist)))

    @klass, @meth = "task", "#blah"

    util_process sexp, 2.0, :something => 1.0, :task => 1.0
  end

  def test_process_iter_dsl_regexp
    # task /regexp/ do
    #   something
    # end

    sexp = s(:iter,
             s(:call, nil, :task, s(:arglist, s(:lit, /regexp/))),
             nil,
             s(:call, nil, :something, s(:arglist)))

    @klass, @meth = "task", "#/regexp/"

    util_process sexp, 2.0, :something => 1.0, :task => 1.0
  end

  def test_process_lit
    sexp = s(:lit, :y)
    util_process sexp, 0.0
  end

  def test_process_lit_int
    sexp = s(:lit, 42)
    util_process sexp, 0.25, :lit_fixnum => 0.25
  end

  def test_process_lit_float # and other lits
    sexp = s(:lit, 3.1415) # TODO: consider penalizing floats if not in cdecl
    util_process sexp, 0.0
  end

  def test_process_lit_bad
    assert_raises RuntimeError do
      @flog.process s(:lit, Object.new)
    end
  end

  def test_process_masgn
    sexp = s(:masgn,
             s(:array, s(:lasgn, :a), s(:lasgn, :b)),
             s(:to_ary, s(:call, nil, :c, s(:arglist))))

    util_process sexp, 3.162, :c => 1.0, :assignment => 3.0
  end

  def test_process_module
    @klass = "X::Y"

    sexp = s(:module,
             s(:colon2, s(:const, :X), :Y),
             s(:scope, s(:lit, 42)))

    util_process sexp, 0.25, :lit_fixnum => 0.25
  end

  def test_process_sclass
    sexp = s(:sclass, s(:self), s(:scope, s(:lit, 42)))
    util_process sexp, 5.375, :sclass => 5.0, :lit_fixnum => 0.375
  end

  def test_process_super
    sexp = s(:super)
    util_process sexp, 1.0, :super => 1.0

    sexp = s(:super, s(:lit, 42))
    util_process sexp, 1.25, :super => 1.0, :lit_fixnum => 0.25
  end

  def test_process_while
    sexp = s(:while,
             s(:call, nil, :a, s(:arglist)),
             s(:call, nil, :b, s(:arglist)),
             true)

    util_process sexp, 2.417, :branch => 1.0, :a => 1.1, :b => 1.1
  end

  def test_process_yield
    sexp = s(:yield)
    util_process sexp, 1.00, :yield => 1.0

    sexp = s(:yield, s(:lit, 4))
    util_process sexp, 1.25, :yield => 1.0, :lit_fixnum => 0.25

    sexp = s(:yield, s(:lit, 42), s(:lit, 24))
    util_process sexp, 1.50, :yield => 1.0, :lit_fixnum => 0.50
  end

  def test_report
    test_flog

    o = StringIO.new
    @flog.report o

    expected = "     1.6: flog total
     1.6: flog/method average

     1.6: main#none
"

    assert_equal expected, o.string
  end

  def test_report_all
    old_stdin = $stdin
    $stdin = StringIO.new "2 + 3"
    $stdin.rewind

    @flog.flog "-"
    @flog.totals["main#something"] = 42.0

    exp = { "main#none" => { :+ => 1.0, :lit_fixnum => 0.6 } }
    assert_equal exp, @flog.calls

    @flog.option[:all] = true

    assert_equal 1.6, @flog.total unless @flog.option[:methods]
    assert_equal 4, @flog.mass["-"] # HACK: 3 is for an unpublished sexp fmt

    o = StringIO.new
    @flog.report o

    expected = "     1.6: flog total
     1.6: flog/method average

     1.6: main#none
"

    assert_equal expected, o.string
    # FIX: add thresholded output
  ensure
    $stdin = old_stdin
  end

  def test_report_group
    # TODO: add second group to ensure proper output
    @flog.option[:group] = true

    test_flog

    o = StringIO.new
    @flog.report o

    expected = "     1.6: flog total
     1.6: flog/method average

     1.6: main total
     1.6: main#none
"

    assert_equal expected, o.string
  end

  def test_score_method
    assert_equal 3.0, @flog.score_method(:blah       => 3.0)
    assert_equal 4.0, @flog.score_method(:assignment => 4.0)
    assert_equal 2.0, @flog.score_method(:branch     => 2.0)
    assert_equal 5.0, @flog.score_method(:blah       => 3.0, # distance formula
                                         :branch     => 4.0)
  end

  def test_signature
    assert_equal "main#none", @flog.signature

    @flog.class_stack << "X"
    assert_equal "X#none", @flog.signature

    @flog.method_stack << "y"
    assert_equal "X#y", @flog.signature

    @flog.class_stack.shift
    assert_equal "main#y", @flog.signature
  end

  def test_total
    @flog.add_to_score "blah", 2
    assert_equal 2.0, @flog.total
  end

  def util_process sexp, score = -1, hash = {}
    setup
    @flog.process sexp

    @klass ||= "main"
    @meth  ||= "#none"

    unless score != -1 && hash.empty? then
      exp = {"#{@klass}#{@meth}" => hash}
      assert_equal exp, @flog.calls
    end

    assert_in_delta score, @flog.total
  end
end
