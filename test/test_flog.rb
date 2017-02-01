require "minitest/autorun"
require "flog"

class Flog
  attr_writer :calls
end

class FlogTest < Minitest::Test
  def setup_flog
    old_stdin = $stdin
    $stdin = StringIO.new "2 + 3"
    $stdin.rewind

    @flog.flog "-"              # @flog can be Flog or FlogCLI
  ensure
    $stdin = old_stdin
  end
end

class TestFlog < FlogTest
  def setup
    @flog = Flog.new :parser => RubyParser
  end

  def test_add_to_score
    assert_empty @flog.calls
    setup_my_klass

    expected = {"MyKlass::Base#mymethod" => {"blah" => 42.0}}
    assert_equal expected, @flog.calls

    @flog.add_to_score "blah", 2

    expected["MyKlass::Base#mymethod"]["blah"] = 44.0
    assert_equal expected, @flog.calls
  end

  def test_average
    test_process_and

    assert_in_epsilon 1.0, @flog.average
  end

  def test_flog
    setup_flog

    exp = { "main#none" => { :+ => 1.0, :lit_fixnum => 0.6 } }
    assert_equal exp, @flog.calls

    assert_in_epsilon 1.6, @flog.total_score unless @flog.option[:methods]
    assert_equal 3, @flog.mass["-"]
  end

  def test_flog_ruby
    ruby = "2 + 3"
    file = "sample.rb"

    @flog.flog_ruby ruby, file
    @flog.calculate_total_scores

    exp = { "main#none" => { :+ => 1.0, :lit_fixnum => 0.6 } }
    assert_equal exp, @flog.calls

    assert_in_epsilon 1.6, @flog.total_score unless @flog.option[:methods]
    assert_equal 3, @flog.mass[file]
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

  def test_penalize_by
    assert_in_epsilon 1, @flog.multiplier
    @flog.penalize_by 2 do
      assert_in_epsilon 3, @flog.multiplier
    end
    assert_in_epsilon 1, @flog.multiplier
  end

  def test_process_alias
    sexp = s(:alias, s(:lit, :a), s(:lit, :b))

    assert_process sexp, 2.0, :alias => 2.0
  end

  def test_process_and
    sexp = s(:and, s(:lit, :a), s(:lit, :b))

    assert_process sexp, 1.0, :branch => 1.0
  end

  def test_process_attrasgn
    sexp = s(:attrasgn,
             s(:call, nil, :a),
             :[]=,
             s(:splat,
               s(:call, nil, :b)),
             s(:call, nil, :c))

    assert_process(sexp, 3.162,
                   :c => 1.0, :b => 1.0, :a => 1.0, :assignment => 1.0)
  end

  # def test_process_attrset
  #   sexp = s(:attrset, :@writer)
  #
  #   assert_process(sexp, 3.162,
  #                  :c => 1.0, :b => 1.0, :a => 1.0, :assignment => 1.0)
  #
  #   flunk "Not yet"
  # end

  def test_process_block
    sexp = s(:block, s(:and, s(:lit, :a), s(:lit, :b)))

    assert_process sexp, 1.1, :branch => 1.1 # 10% penalty over process_and
  end

  def test_process_block_pass
    sexp = s(:call, nil, :a,
             s(:block_pass,
               s(:call, nil, :b)))

    bonus = case RUBY_VERSION
            when /^1\.8\.7/ then 0.4
            when /^1\.9/    then 0.3
            when /^2\./     then 0.2
            else raise "Unhandled version #{RUBY_VERSION}"
            end

    bonus += Flog::OTHER_SCORES[:to_proc_normal]

    assert_process(sexp, 3.4 + bonus,
                   :a              => 1.0,
                   :block_pass     => 1.2,
                   :b              => 1.2,
                   :to_proc_normal => 0.0 + bonus)
  end

  def test_process_block_pass_colon2
    sexp = s(:call, nil, :a,
             s(:block_pass,
               s(:colon2, s(:const, :A), :B)))

    assert_process(sexp, 2.2,
                   :a              => 1.0,
                   :block_pass     => 1.2)
  end

  def test_process_block_pass_iter
    sexp = s(:block_pass,
             s(:iter, s(:call, nil, :lambda), nil, s(:lit, 1)))

    assert_process(sexp, 12.316,
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
               s(:iter, s(:call, nil, :lambda), nil, s(:lit, 1))))

    assert_process(sexp, 17.333,
                   :lit_fixnum    =>  0.275,
                   :block_pass    =>  1.0,
                   :lambda        =>  1.0,
                   :assignment    =>  1.0,
                   :branch        =>  1.0,
                   :to_proc_lasgn => 15.0)
  end

  def test_process_call
    sexp = s(:call, nil, :a)
    assert_process sexp, 1.0, :a => 1.0
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

    assert_process sexp, 2.1, :branch => 2.1
  end

  def test_process_class
    @klass = "X::Y"

    sexp = s(:class,
             s(:colon2, s(:const, :X), :Y), nil,
             s(:scope, s(:lit, 42)))

    assert_process sexp, 0.25, :lit_fixnum => 0.25
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

    assert_process sexp, 0.275, :lit_fixnum => 0.275
  end

  def test_process_defn_in_self
    sexp = s(:sclass, s(:self),
             s(:defn, :x,
               s(:args, :y),
                 s(:lit, 42)))

    setup
    @flog.process sexp
    @flog.calculate_total_scores

    exp = {'main::x' => {:lit_fixnum => 0.375}, 'main#none' => {:sclass => 5.0}}
    assert_equal exp, @flog.calls

    assert_in_delta 5.375, @flog.total_score
  end

  def test_process_defn_in_self_after_self
    sexp = s(:sclass, s(:self),
             s(:sclass, s(:self), s(:self)),
             s(:defn, :x,
               s(:args, :y),
                 s(:lit, 42)))

    setup
    @flog.process sexp
    @flog.calculate_total_scores

    exp = {'main::x' => {:lit_fixnum => 0.375}, 'main#none' => {:sclass => 12.5}}
    assert_equal exp, @flog.calls

    assert_in_delta 12.875, @flog.total_score
  end

  def test_process_defs
    @meth = "::x" # HACK, I don't like this

    sexp = s(:defs, s(:self), :x,
             s(:args, :y),
             s(:scope,
               s(:block,
                 s(:lit, 42))))

    assert_process sexp, 0.275, :lit_fixnum => 0.275
  end

  # FIX: huh? over-refactored?
  # def test_process_else
  #   flunk "Not yet"
  # end

  def test_process_if
    sexp = s(:if,
             s(:call, nil, :b), # outside block, not penalized
             s(:call, nil, :a), nil)

    assert_process sexp, 2.326, :branch => 1.0, :b => 1.0, :a => 1.1
  end

  def test_process_iter
    sexp = s(:iter,
             s(:call, nil, :loop), nil,
             s(:if, s(:true), s(:break), nil))

    assert_process sexp, 2.326, :loop => 1.0, :branch => 2.1
  end

  def test_process_iter_dsl
    # task :blah do
    #   something
    # end

    sexp = s(:iter,
             s(:call, nil, :task, s(:lit, :blah)),
             nil,
             s(:call, nil, :something))

    @klass, @meth = "task", "#blah"

    assert_process sexp, 2.0, :something => 1.0, :task => 1.0
  end

  def test_process_iter_dsl_regexp
    # task /regexp/ do
    #   something
    # end

    sexp = s(:iter,
             s(:call, nil, :task, s(:lit, /regexp/)),
             nil,
             s(:call, nil, :something))

    @klass, @meth = "task", "#/regexp/"

    assert_process sexp, 2.0, :something => 1.0, :task => 1.0
  end

  def test_process_iter_dsl_hash
    # task :woot => 42 do
    #   something
    # end

    sexp = s(:iter,
             s(:call, nil, :task, s(:hash, s(:lit, :woot), s(:lit, 42))),
             nil,
             s(:call, nil, :something))

    @klass, @meth = "task", "#woot"

    assert_process sexp, 2.3, :something => 1.0, :task => 1.0, :lit_fixnum => 0.3
  end

  def test_process_iter_dsl_namespaced
    # namespace :blah do
    #   task :woot => 42 do
    #     something
    #   end
    # end

    sexp = s(:iter,
             s(:call, nil, :namespace, s(:lit, :blah)),
             nil,
             s(:iter,
               s(:call, nil, :task, s(:hash, s(:lit, :woot), s(:lit, 42))),
               nil,
               s(:call, nil, :something)))

    @klass, @meth = "namespace(blah)::task", "woot"

    score = 3.3
    hash  = {
      "namespace(blah)::task#woot" => {
        :something  => 1.0,
        :lit_fixnum => 0.3,
        :task       => 1.0,
      },
      "namespace#blah" => {
        :namespace => 1.0,
      },
    }

    setup
    @flog.process sexp
    @flog.calculate_total_scores

    assert_equal hash, @flog.calls
    assert_in_delta score, @flog.total_score
  end

  def test_process_lit
    sexp = s(:lit, :y)
    assert_process sexp, 0.0
  end

  def test_process_lit_int
    sexp = s(:lit, 42)
    assert_process sexp, 0.25, :lit_fixnum => 0.25
  end

  def test_process_lit_float # and other lits
    sexp = s(:lit, 3.1415) # TODO: consider penalizing floats if not in cdecl
    assert_process sexp, 0.0
  end

  def test_process_lit_bad
    assert_raises RuntimeError do
      @flog.process s(:lit, Object.new)
    end
  end

  def test_process_masgn
    sexp = s(:masgn,
             s(:array, s(:lasgn, :a), s(:lasgn, :b)),
             s(:to_ary, s(:call, nil, :c)))

    assert_process sexp, 3.162, :c => 1.0, :assignment => 3.0
  end

  def test_process_module
    @klass = "X::Y"

    sexp = s(:module,
             s(:colon2, s(:const, :X), :Y),
             s(:scope, s(:lit, 42)))

    assert_process sexp, 0.25, :lit_fixnum => 0.25
  end

  def test_process_sclass
    sexp = s(:sclass, s(:self), s(:scope, s(:lit, 42)))
    assert_process sexp, 5.375, :sclass => 5.0, :lit_fixnum => 0.375
  end

  def test_process_super
    sexp = s(:super)
    assert_process sexp, 1.0, :super => 1.0

    sexp = s(:super, s(:lit, 42))
    assert_process sexp, 1.25, :super => 1.0, :lit_fixnum => 0.25
  end

  def test_process_while
    sexp = s(:while,
             s(:call, nil, :a),
             s(:call, nil, :b),
             true)

    assert_process sexp, 2.417, :branch => 1.0, :a => 1.1, :b => 1.1
  end

  def test_process_yield
    sexp = s(:yield)
    assert_process sexp, 1.00, :yield => 1.0

    sexp = s(:yield, s(:lit, 4))
    assert_process sexp, 1.25, :yield => 1.0, :lit_fixnum => 0.25

    sexp = s(:yield, s(:lit, 42), s(:lit, 24))
    assert_process sexp, 1.50, :yield => 1.0, :lit_fixnum => 0.50
  end

  def test_score_method
    assert_in_epsilon 3.0, @flog.score_method(:blah       => 3.0)
    assert_in_epsilon 4.0, @flog.score_method(:assignment => 4.0)
    assert_in_epsilon 2.0, @flog.score_method(:branch     => 2.0)
    assert_in_epsilon 5.0, @flog.score_method(:blah       => 3.0, # distance formula
                                              :branch     => 4.0)
  end

  def test_total_score
    @flog.add_to_score "blah", 2
    @flog.calculate_total_scores

    assert_in_epsilon 2.0, @flog.total_score
  end

  def test_max_method
    @flog.calls = {
      "main#none" => {"foo" => 2.0, "bar" => 4.0},
      "main#meth_one" => {"foo" => 1.0, "bar" => 1.0},
      "main#meth_two" => {"foo" => 2.0, "bar" => 14.0},
    }

    @flog.calculate_total_scores
    assert_equal ["main#meth_two", 16.0], @flog.max_method
  end

  def test_max_score
    @flog.calls = {
      "main#none"     => {"foo" => 2.0, "bar" => 4.0},
      "main#meth_one" => {"foo" => 1.0, "bar" => 1.0},
      "main#meth_two" => {"foo" => 2.0, "bar" => 14.0},
    }
    @flog.calculate_total_scores

    assert_in_epsilon 16.0, @flog.max_score
  end

  def assert_hash_in_epsilon exp, act
    assert_equal exp.keys.sort_by(&:to_s), act.keys.sort_by(&:to_s)

    exp.keys.each do |k|
      assert_in_epsilon exp[k], act[k], 0.001, "key = #{k.inspect}"
    end
  end

  def assert_process sexp, score = -1, hash = {}
    setup
    @flog.process sexp

    @klass ||= "main"
    @meth  ||= "#none"

    unless score != -1 && hash.empty? then
      key = "#{@klass}#{@meth}"
      act = @flog.calls

      assert_equal [key], act.keys.sort
      assert_hash_in_epsilon hash, act[key]
    end

    @flog.calculate_total_scores

    assert_in_epsilon score, @flog.total_score
  end

  def test_threshold
    test_flog
    assert_in_epsilon 0.6 * 1.6, @flog.threshold
  end

  def test_no_threshold
    @flog.option[:all] = true
    assert_nil @flog.threshold
  end

  def test_threshold_custom
    @flog.threshold = 0.33

    test_flog
    assert_in_epsilon 0.33 * 1.6, @flog.threshold
  end

  def test_calculate
    setup_my_klass

    @flog.calculate_total_scores
    @flog.calculate

    assert_equal({ 'MyKlass::Base' => 42.0 }, @flog.scores)
    assert_equal({ 'MyKlass::Base' => [["MyKlass::Base#mymethod", 42.0]] }, @flog.method_scores)
  end

  def test_reset
    user_class = %(
        class User
          def blah n
            puts "blah" * n
          end
        end
      )
    user_file = "user.rb"

    @flog.flog_ruby user_class, user_file
    @flog.calculate_total_scores
    @flog.calculate

    assert_equal({ 'User#blah' => 'user.rb:3-4' }, @flog.method_locations)
    assert_equal({ "User#blah" => 2.2 }, @flog.totals)
    assert_in_epsilon(2.2, @flog.total_score)
    assert_in_epsilon(1.0, @flog.multiplier)
    assert_equal({ "User#blah" => { :* => 1.2, :puts => 1.0 } }, @flog.calls)
    assert_equal({ "User" => 2.2 }, @flog.scores)

    @flog.reset

    coder_class = %(
        class Coder
          def happy?
            [true, false].sample
          end
        end
      )
    coder_file = "coder.rb"

    @flog.flog_ruby coder_class, coder_file
    @flog.calculate_total_scores
    @flog.calculate

    assert_equal({ 'Coder#happy?' => 'coder.rb:3-4' }, @flog.method_locations)
    assert_equal({ "Coder#happy?" => 1.0 }, @flog.totals)
    assert_in_epsilon(1.0, @flog.total_score)
    assert_in_epsilon(1.0, @flog.multiplier)
    assert_equal({ "Coder#happy?" => { :sample => 1.0 } }, @flog.calls)
    assert_equal({ "Coder" => 1.0 }, @flog.scores)
  end

  def test_method_scores
    user_class = %(
      module User
        class Account
          def blah n
            puts "blah" * n
          end
        end

        class Profile
          def bleh n
            puts "bleh" * n
          end
        end
      end
    )
    user_file = "user.rb"

    @flog.flog_ruby user_class, user_file
    @flog.calculate_total_scores
    @flog.calculate

    expected = {
      "User::Account"=>[["User::Account#blah", 2.2]],
      "User::Profile"=>[["User::Profile#bleh", 2.2]]
    }
    assert_equal(expected, @flog.method_scores)
  end

  def setup_my_klass
    @flog.class_stack  << "Base" << "MyKlass"
    @flog.method_stack << "mymethod"
    @flog.add_to_score "blah", 42
  end
end
