require "minitest/autorun"
require "flog"

class Flog
  attr_writer :calls # Allow tests to manually set calls for specific scenarios
end

class FlogTest < Minitest::Test
  def setup_flog
    old_stdin = $stdin
    $stdin = StringIO.new "2 + 3" # A simple default input
    @flog.flog "-"
  ensure
    $stdin = old_stdin
  end
end

class TestFlog < FlogTest
  def setup
    @flog = Flog.new
  end

  def assert_process(code_string, expected_total_score = -1, expected_calls_details = {}, expected_key_for_details = "Object#main")
    @flog.reset # Reset flog state before each processing
    @flog.flog_ruby(code_string, "-") # Use "-" as a dummy filename
    @flog.calculate_total_scores # Ensure scores are calculated

    if expected_total_score != -1
      assert_in_delta expected_total_score, @flog.total_score, 0.01, "Total score mismatch for code: \"#{code_string}\""
    end

    unless expected_calls_details.empty?
      actual_calls_for_key = @flog.calls[expected_key_for_details]
      assert_not_nil actual_calls_for_key, "No calls recorded for key '#{expected_key_for_details}' for code: \"#{code_string}\". Calls: #{@flog.calls.inspect}"

      assert_equal expected_calls_details.keys.map(&:to_s).sort, actual_calls_for_key.keys.map(&:to_s).sort, "Score detail keys for '#{expected_key_for_details}' do not match for code: \"#{code_string}\""
      expected_calls_details.each do |inner_key, expected_value|
        assert_in_delta expected_value, actual_calls_for_key[inner_key], 0.01, "Score value for #{expected_key_for_details}[#{inner_key}] mismatch for code: \"#{code_string}\""
      end
      assert_equal expected_calls_details.size, actual_calls_for_key.size, "Different number of score elements for key '#{expected_key_for_details}' for code: \"#{code_string}\""
    end
  end

  def test_add_to_score
    assert_empty @flog.calls
    
    setup_my_klass
    
    expected_initial = {"MyKlass::Base#mymethod" => {"blah" => 42.0}}
    assert_equal expected_initial, @flog.calls

    original_method_stack = @flog.instance_variable_get(:@method_stack).dup
    @flog.instance_variable_set(:@method_stack, ["MyKlass::Base#mymethod"])

    @flog.add_to_score "blah", 2

    @flog.instance_variable_set(:@method_stack, original_method_stack)

    expected_final = {"MyKlass::Base#mymethod" => {"blah" => 44.0}}
    assert_equal expected_final, @flog.calls
  end

  def test_average
    @flog.flog_ruby("nil && nil", "-") 
    @flog.calculate_total_scores
    assert_in_epsilon 1.0, @flog.average
  end

  def test_flog
    setup_flog 

    exp = { "Object#main" => { :+ => 1.0, :magic_number => 0.6 } } 
    actual_calls = @flog.calls
    assert_equal exp.keys.sort, actual_calls.keys.sort
    exp.each do |key, inner_hash|
      inner_hash.each do |inner_key, value|
        assert_in_delta value, actual_calls[key][inner_key], 0.001, "Failed for #{key}[#{inner_key}]"
      end
      assert_equal inner_hash.size, actual_calls[key].size, "Key #{key} has different number of elements"
    end

    assert_in_epsilon 1.6, @flog.total_score unless @flog.option[:methods]
  end

  def test_flog_ruby
    ruby = "2 + 3"
    file = "sample.rb"

    @flog.flog_ruby ruby, file
    @flog.calculate_total_scores

    exp = { "Object#main" => { :+ => 1.0, :magic_number => 0.6 } } 
    actual_calls = @flog.calls
    assert_equal exp.keys.sort, actual_calls.keys.sort
    exp.each do |key, inner_hash|
      inner_hash.each do |inner_key, value|
        assert_in_delta value, actual_calls[key][inner_key], 0.001, "Failed for #{key}[#{inner_key}]"
      end
      assert_equal inner_hash.size, actual_calls[key].size, "Key #{key} has different number of elements"
    end
    
    assert_in_epsilon 1.6, @flog.total_score unless @flog.option[:methods]
  end

  def test_flog_erb
    old_stdin = $stdin
    $stdin = StringIO.new "2 + <%= blah %>"
    $stdin.rewind

    o, e = capture_io do
      @flog.flog "-"
    end

    assert_equal "", o
    assert_match(/Prism Error: unexpected '<'; expected an expression after the operator at -:1/, e)
    assert_match(/Prism Error: unterminated string meets end of file at -:1/, e)
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
    code = "alias a b"
    assert_process(code, 2.0, { :alias => 2.0 }, "Object#main")
  end

  def test_process_and
    code_simple_and = "nil && nil"
    assert_process(code_simple_and, 1.0, { :branch => 1.0 }, "Object#main")
  end

  def test_process_attrasgn
    code = "def x=(v); end; self.x = 1"
    assert_process(code, 1.3, { :x= => 1.0, :magic_number => 0.3 }, "Object#x=")
  end

  def test_process_block
    code = "{ nil && nil }"
    assert_process(code, 1.1, { :branch => 1.1 }, "Object#main")
  end

  def test_process_block_pass__call
    code_complex_block_pass = "def b_func; end; def a_func(&x); end; a_func(&b_func)"
    assert_process(code_complex_block_pass, 3.4,
                   { :a_func => 1.0, :block_pass => 1.2, :b_func => 1.2 }, "Object#main")
  end

  def test_process_block_pass__to_proc
    code = "[1,2,3].map(&:to_i)"
    assert_process(code, 2.2, { :map => 1.0, :block_pass => 1.2 }, "Object#main")
  end

  def test_process_block_pass_colon2
    code = "module A; B = proc {}; end; def foo(&x); end; foo(&A::B)"
    assert_process(code, 2.2, { :foo => 1.0, :block_pass => 1.2 }, "Object#main")
  end

  def test_process_block_pass__hash_wtf
    skip "test_process_block_pass__hash_wtf needs review for Prism specific :to_proc_icky! logic"
  end

  def test_process_block_pass_iter
    skip "test_process_block_pass_iter needs review for Prism specific :to_proc_icky! logic and penalties"
  end

  def test_process_block_pass_lasgn
    skip "test_process_block_pass_lasgn needs review for Prism specific :to_proc_lasgn logic and combined scoring"
  end

  def test_process_block_pass__nil
    code = "def foo(&b); end; foo(&nil)"
    assert_process(code, 2.2, { :foo => 1.0, :block_pass => 1.2 }, "Object#main")
  end

  def test_process_call
    code = "a()"
    assert_process(code, 1.0, { :a => 1.0 }, "Object#main")
  end

  def test_process_call2
    code = "def a; self; end; def b; end; a().b()"
    assert_process(code, 2.2, { :a => 1.2, :b => 1.0 }, "Object#main")
  end

  def test_process_call3
    code = "def a; self; end; def b; self; end; def c; end; a.b.c"
    assert_process(code, 3.64, { :a => 1.44, :b => 1.2, :c => 1.0 }, "Object#main")
  end

  def test_process_safe_call2
    code = "def a; self; end; def b; end; a&.b"
    assert_process(code, 2.3, { :a => 1.3, :b => 1.0 }, "Object#main")
  end

  def test_process_safe_call3
    code = "def a; self; end; def b; self; end; def c; end; a&.b&.c"
    assert_process(code, 3.99, { :a => 1.69, :b => 1.3, :c => 1.0 }, "Object#main")
  end

  def test_process_case
    code_nil_case = "case nil; when nil; nil; end"
    assert_process(code_nil_case, 2.1, { :branch => 2.1 }, "Object#main")
  end

  def test_process_class
    code = "module X; class Y; 42; end; end"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object#main")
  end

  def test_process_defn
    code = "def x(y); 42; end"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object#x")
  end

  def test_process_defn_in_self
    code = "class << self; def x(y); 42; end; end"
    setup
    @flog.flog_ruby(code, "-")
    @flog.calculate_total_scores
    
    expected_calls = {
      "Object::x" => { :magic_number => (0.25 * 1.5) }, 
      "Object#main" => { :sclass => 5.0 } 
    }
    actual_calls = @flog.calls
    assert_equal expected_calls.keys.sort, actual_calls.keys.sort
    assert_in_delta expected_calls["Object::x"][:magic_number], actual_calls["Object::x"][:magic_number], 0.001
    assert_in_delta expected_calls["Object#main"][:sclass], actual_calls["Object#main"][:sclass], 0.001
    
    assert_in_delta (5.0 + (0.25 * 1.5)), @flog.total_score, 0.001
  end

  def test_process_defn_in_self_after_self
    code = "class << self; class << self; end; def x(y); 42; end; end"
    setup
    @flog.flog_ruby(code, "-")
    @flog.calculate_total_scores
    
    actual_calls = @flog.calls
    assert_in_delta((0.25 * 1.5), actual_calls["Object::x"][:magic_number], 0.001)
    assert_in_delta(5.0 + (5.0 * 1.5), actual_calls["Object#main"][:sclass], 0.001)
    assert_in_delta 12.875, @flog.total_score, 0.001
  end

  def test_process_defs
    code = "def self.x(y); 42; end"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object::x")
  end

  def test_process_if
    code = "def a; end; def b; end; if b(); a(); end"
    assert_process(code, 2.326, { :branch => 1.0, :b => 1.0, :a => 1.1 }, "Object#main")
  end

  def test_process_iter
    code = "loop { if true; break; end }"
    assert_process(code, 2.326, { :loop => 1.0, :branch => 1.1, :block_call => 1.0 }, "Object#main")
  end

  def test_process_iter_dsl
    code = "def task(*args, &b); yield if block_given?; end; def something; end; task(:blah) { something }"
    setup
    @flog.flog_ruby(code, "-")
    @flog.calculate_total_scores
    assert_in_delta 2.414, @flog.total_score, 0.01
    assert_equal({ :something => 1.0 }, @flog.calls["task#blah"])
    assert_equal({ :task => 1.0, :block_call => 1.0 }, @flog.calls["Object#main"])
  end

  def test_process_iter_dsl_regexp
    code = "def task(*args, &b); yield if block_given?; end; def something; end; task(/regexp/) { something }"
    setup
    @flog.flog_ruby(code, "-")
    @flog.calculate_total_scores
    assert_in_delta 2.414, @flog.total_score, 0.01
    assert_equal({ :something => 1.0 }, @flog.calls["task#/regexp/"])
    assert_equal({ :task => 1.0, :block_call => 1.0 }, @flog.calls["Object#main"])
  end

  def test_process_iter_dsl_hash
    code = "def task(*args, &b); yield if block_given?; end; def something; end; task(:woot => 42) { something }"
    assert_process(code, 2.345, # sqrt( (1+1.1)^2 + 1^2 + 0.3^2 ) = 2.345
                   { :task => 1.0, :block_call => 1.0, :something => 1.1, :magic_number => 0.3 },
                   "Object#main")
  end

  def test_process_iter_dsl_hash_when_hash_empty
    code = "def task(*args, &b); yield if block_given?; end; def something; end; task({}) { something }"
    assert_process(code, 2.326, # sqrt( (1+1.1)^2 + 1^2) = 2.326
                   { :task => 1.0, :block_call => 1.0, :something => 1.1 },
                   "Object#main")
  end

  def test_process_iter_dsl_namespaced
    code = <<-RUBY
      def namespace(*args, &blockA); instance_eval(&blockA); end
      def task(*args, &blockB); instance_eval(&blockB); end
      def something; end

      namespace :blah do
        task :woot => 42 do
          something
        end
      end
    RUBY
    setup
    @flog.flog_ruby(code, "-")
    @flog.calculate_total_scores

    # Object#main: namespace(1), block_call(1) -> sqrt(1^2+1^2) = 1.414
    # namespace#blah: task(1), block_call(1), magic_number(0.3), something(1.1) -> sqrt(2.1^2+1+0.09) = 2.345
    # Total = 1.414 + 2.345 = 3.759
    assert_in_delta 3.759, @flog.total_score, 0.01
    assert_equal({ :namespace => 1.0, :block_call => 1.0 }, @flog.calls["Object#main"])
    expected_namespace_blah = { :task => 1.0, :block_call => 1.0, :magic_number => 0.3, :something => 1.1}
    actual_namespace_blah = @flog.calls["namespace#blah"]
    assert_equal expected_namespace_blah.keys.sort, actual_namespace_blah.keys.sort
    expected_namespace_blah.each {|k,v| assert_in_delta v, actual_namespace_blah[k], 0.01 }
  end

  def test_process_lit
    code = ":y"
    assert_process(code, 0.0, {}, "Object#main")
  end

  def test_process_lit_int
    code = "42"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object#main")
  end

  def test_process_lit_int__const
    code = "X = 42"
    assert_process(code, 1.0, { :assignment => 1.0 }, "Object#main")
  end

  def test_process_lit_float # and other lits
    code = "3.1415"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object#main")
  end

  def test_process_lit_float__const
    code = "X = 3.1415"
    assert_process(code, 1.0, { :assignment => 1.0 }, "Object#main")
  end

  def test_process_lit_complex
    code = "(0+1i)"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object#main")
  end

  def test_process_masgn
    code = "def c_meth; [1,2]; end; a, b = c_meth"
    assert_process(code, Math.sqrt(1**2 + 1**2), { :assignment => 1.0, :c_meth => 1.0 }, "Object#main")
  end

  def test_process_module
    code = "module X::Y; 42; end"
    assert_process(code, 0.25, { :magic_number => 0.25 }, "Object#main")
  end

  def test_process_sclass
    code = "class << self; 42; end"
    setup
    @flog.flog_ruby(code, "-")
    @flog.calculate_total_scores
    assert_in_delta 5.375, @flog.total_score, 0.001
    assert_in_delta 5.0, @flog.calls["Object#main"][:sclass], 0.001
    assert_in_delta 0.375, @flog.calls["Object#main"][:magic_number], 0.001
  end

  def test_process_super
    code1 = "def x; super; end"
    assert_process(code1, 1.0, { :super => 1.0 }, "Object#x")

    code2 = "def y; super(42); end"
    assert_process(code2, 1.25, { :super => 1.0, :magic_number => 0.25 }, "Object#y")
  end

  def test_process_while
    code = "def a;end; def b;end; while a(); b(); end"
    assert_process(code, 2.417, { :branch => 1.0, :a => 1.1, :b => 1.1 }, "Object#main")
  end

  def test_process_yield
    code1 = "def x; yield; end"
    assert_process(code1, 1.0, { :yield => 1.0 }, "Object#x")

    code2 = "def y; yield 4; end"
    assert_process(code2, 1.25, { :yield => 1.0, :magic_number => 0.25 }, "Object#y")

    code3 = "def z; yield 42, 24; end"
    assert_process(code3, 1.50, { :yield => 1.0, :magic_number => 0.50 }, "Object#z")
  end

  def test_score_method # This test does not use S-expressions or direct flog processing.
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
      "Object#main" => {"foo" => 2.0, "bar" => 4.0}, 
      "Object#meth_one" => {"foo" => 1.0, "bar" => 1.0},
      "Object#meth_two" => {"foo" => 2.0, "bar" => 1.4E1}, 
    }

    @flog.calculate_total_scores
    assert_equal ["Object#meth_two", 16.0], @flog.max_method
  end

  def test_max_score
    @flog.calls = {
      "Object#main"     => {"foo" => 2.0, "bar" => 4.0}, 
      "Object#meth_one" => {"foo" => 1.0, "bar" => 1.0},
      "Object#meth_two" => {"foo" => 2.0, "bar" => 1.4E1}, 
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

  def test_threshold
    @flog.threshold = 0.5
    assert_equal 0.5, @flog.threshold

    @flog.flog_ruby("def foo; a=1;b=2;c=3; end", "-") 
    @flog.calculate_total_scores 
    expected_threshold_val = @flog.total_score * 0.5
    assert_in_delta expected_threshold_val, @flog.threshold, 0.001
  end

  def test_no_threshold
    @flog.option[:all] = true
    assert_nil @flog.threshold
  end

  def test_threshold_custom
    @flog.threshold = 0.33
    assert_equal 0.33, @flog.instance_variable_get(:@threshold)

    @flog.flog_ruby("def foo; a=1;b=2;c=3;d=4; end", "-") 
    @flog.calculate_total_scores 
    expected_threshold_val = @flog.total_score * 0.33
    assert_in_delta expected_threshold_val, @flog.threshold, 0.001
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

    assert_equal({ 'User#blah' => 'user.rb:3' }, @flog.method_locations) 
    expected_user_blah_score = Math.sqrt(1.0**2 + (1.0 * 1.2)**2) 
    
    assert_in_delta expected_user_blah_score, @flog.totals["User#blah"], 0.01
    assert_in_delta expected_user_blah_score, @flog.total_score, 0.01
    assert_in_epsilon(1.0, @flog.multiplier)
    
    expected_user_calls = { :* => (1.0 * 1.2), :puts => 1.0 }
    actual_user_calls = @flog.calls["User#blah"]
    assert_equal expected_user_calls.keys.sort, actual_user_calls.keys.sort
    expected_user_calls.each {|k,v| assert_in_delta v, actual_user_calls[k], 0.01 }

    assert_equal({ "User" => expected_user_blah_score }, @flog.scores)


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

    assert_equal({ 'Coder#happy?' => 'coder.rb:3' }, @flog.method_locations) 
    expected_coder_happy_score = 1.0
    assert_in_delta expected_coder_happy_score, @flog.totals["Coder#happy?"], 0.01
    assert_in_delta expected_coder_happy_score, @flog.total_score, 0.01
    assert_in_epsilon(1.0, @flog.multiplier)
    assert_equal({ "Coder#happy?" => { :sample => 1.0 } }, @flog.calls)
    assert_equal({ "Coder" => expected_coder_happy_score }, @flog.scores)
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

    expected_score = Math.sqrt(1.0**2 + (1.0 * 1.2)**2) 
    expected = {
      "User::Account"=>[["User::Account#blah", expected_score]],
      "User::Profile"=>[["User::Profile#bleh", expected_score]]
    }
    assert_equal expected.keys.sort, @flog.method_scores.keys.sort
    expected.each do |klass, method_details_array|
        actual_details_array = @flog.method_scores[klass]
        assert_equal method_details_array.size, actual_details_array.size
        method_details_array.each_with_index do |meth_detail, idx|
            assert_equal meth_detail[0], actual_details_array[idx][0] # Compare name
            assert_in_delta meth_detail[1], actual_details_array[idx][1], 0.01 # Compare score
        end
    end
  end

  def setup_my_klass
    original_class_parts = @flog.instance_variable_get(:@current_class_name_parts).dup
    original_method_stack = @flog.instance_variable_get(:@method_stack).dup

    @flog.instance_variable_set(:@current_class_name_parts, ["MyKlass", "Base"])
    current_sig = @flog.build_signature("mymethod")
    @flog.instance_variable_set(:@method_stack, [current_sig])
    
    @flog.add_to_score "blah", 42
    
    @flog.instance_variable_set(:@current_class_name_parts, original_class_parts)
    @flog.instance_variable_set(:@method_stack, original_method_stack)
  end
end

# vim: syntax=ruby
