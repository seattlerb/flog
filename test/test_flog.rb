require 'test/test_helper'
require 'flog'
require 'sexp_processor'

class Flog
  attr_writer :total_score
end

class TestFlog < MiniTest::Unit::TestCase
  def setup
    @flog = Flog.new
  end

#   def test_sanity
#     # FIX: make this easy to pass in to Flog.new
#     ARGV.push("-a")
#     opts = Flog.parse_options
#     ARGV.clear
#     @flog.flog __FILE__
#
#     test_methods = self.class.instance_methods(false).sort.map { |m|
#       "#{self.class}##{m}"
#     }
#
#     expected_calls = ["Flog#none"] + test_methods + ["main#none"]
#
#     assert_in_delta 1.0, @flog.multiplier, 0.001
#     assert_equal expected_calls, @flog.calls.keys.sort
#     assert_equal 1, @flog.mass.size
#     assert_operator @flog.mass[__FILE__], :>, 100
#     assert_equal [], @flog.class_stack
#     assert_equal [], @flog.method_stack
#
#     # FIX: this sucks, but it is a start.
#     out = StringIO.new
#     @flog.report out
#     out = out.string
#
#     assert_match(/[\d\.]+: flog total/, out)
#     assert_match(/[\d\.]+: flog.method average/, out)
#
#     test_methods.each do |m|
#       assert_match(/[\d\.]+: #{m}/, out)
#     end
#   end

  def test_class_expand_dirs_to_files
    expected = %w(lib/flog.rb lib/flog_task.rb lib/gauntlet_flog.rb)
    assert_equal expected, Flog.expand_dirs_to_files('lib')
    expected = %w(Rakefile)
    assert_equal expected, Flog.expand_dirs_to_files('Rakefile')
  end

  def test_class_parse_options
    d = Flog.default_options
    assert_equal d, Flog.parse_options

    options = {
      "-a" => :all,
      "-b" => :blame,
      "-c" => :continue,
      "-d" => :details,
      "-g" => :group,
      "-m" => :methods,
      "-q" => :quiet,
      "-s" => :score,
      "-v" => :verbose,
    }

    options.each do |arg, opt|
      ARGV.replace [arg]
      assert_equal d.merge(opt => true), Flog.parse_options
    end

    old_load_path = $:.dup
    ARGV.replace ["-Iblah1,blah2"]
    assert_equal d, Flog.parse_options
    assert_equal old_load_path + %w(blah1 blah2), $:

    def Flog.exit
      raise "happy"
    end

    ex = nil
    o, e = capture_io do
      ex = assert_raises RuntimeError do
        ARGV.replace ["-h"]
        Flog.parse_options
      end
    end
    assert_equal "happy", ex.message
    assert_match(/methods-only/, o)
    assert_equal "", e
  ensure
    ARGV.clear
  end

  def test_add_to_score
    assert_empty @flog.calls
    @flog.class_stack  << "MyKlass"
    @flog.method_stack << "mymethod"
    @flog.add_to_score "blah", 42

    expected = {"MyKlass#mymethod"=>{"blah"=>42.0}}
    assert_equal expected, @flog.calls

    @flog.add_to_score "blah", 2

    expected["MyKlass#mymethod"]["blah"] = 44.0
    assert_equal expected, @flog.calls
  end

#   def test_analyze_list
#     raise NotImplementedError, 'Need to write test_analyze_list'
#   end

  def test_average
    assert_equal 0, Flog.new.average
    # TODO: non-zero... but do total/totals first
  end

  def test_calls
    expected = {}
    assert_equal expected, Flog.new.calls
  end

#   def test_flog
#     raise NotImplementedError, 'Need to write test_flog'
#   end

  def test_in_klass
    assert_empty @flog.class_stack

    @flog.in_klass "xxx" do
      assert_equal ["xxx"], @flog.class_stack
    end

    assert_empty @flog.class_stack
  end

  def test_in_method
    assert_empty @flog.method_stack

    @flog.in_method "xxx" do
      assert_equal ["xxx"], @flog.method_stack
    end

    assert_empty @flog.method_stack
  end

#   def test_increment_total_score_by
#     raise NotImplementedError, 'Need to write test_increment_total_score_by'
#   end
#
#   def test_klass_name
#     raise NotImplementedError, 'Need to write test_klass_name'
#   end
#
#   def test_mass
#     raise NotImplementedError, 'Need to write test_mass'
#   end
#
#   def test_method_name
#     raise NotImplementedError, 'Need to write test_method_name'
#   end
#
#   def test_method_stack
#     raise NotImplementedError, 'Need to write test_method_stack'
#   end
#
#   def test_multiplier
#     raise NotImplementedError, 'Need to write test_multiplier'
#   end
#
#   def test_multiplier_equals
#     raise NotImplementedError, 'Need to write test_multiplier_equals'
#   end
#
#   def test_options
#     raise NotImplementedError, 'Need to write test_options'
#   end
#
#   def test_output_details
#     raise NotImplementedError, 'Need to write test_output_details'
#   end
#
#   def test_output_method_details
#     raise NotImplementedError, 'Need to write test_output_method_details'
#   end
#
#   def test_output_summary
#     raise NotImplementedError, 'Need to write test_output_summary'
#   end
#
#   def test_parse_tree
#     raise NotImplementedError, 'Need to write test_parse_tree'
#   end

  def test_penalize_by
    assert_equal 1, @flog.multiplier
    @flog.penalize_by 2 do
      assert_equal 3, @flog.multiplier
    end
    assert_equal 1, @flog.multiplier
  end

#   def test_record_method_score
#     raise NotImplementedError, 'Need to write test_record_method_score'
#   end
#
#   def test_report
#     raise NotImplementedError, 'Need to write test_report'
#   end
#
#   def test_reset
#     raise NotImplementedError, 'Need to write test_reset'
#   end

  def test_score_method
    expected = 3.742
    assert_in_delta expected, @flog.score_method(:assignment => 1,
                                                 :branch     => 2,
                                                 :other      => 3)
  end

#   def test_summarize_method
#     raise NotImplementedError, 'Need to write test_summarize_method'
#   end
#
#   def test_total
#     raise NotImplementedError, 'Need to write test_total'
#   end
#
#   def test_totals
#     raise NotImplementedError, 'Need to write test_totals'
#   end
end

# Number of errors detected: 64

# describe Flog do
#   before :each do
#     @options = { }
#     @flog = Flog.new(@options)
#   end
#
# #   describe 'when initializing' do
# #     it 'should not reference the parse tree' do
# #       ParseTree.expects(:new).never
# #       Flog.new(@options)
# #     end
# #   end
#
#   describe 'after initializing' do
#     it 'should have options set' do
#       @flog.options.must_equal @options
#     end
#
#     it 'should return an SexpProcessor' do
#       @flog.must_be_kind_of(SexpProcessor)
#     end
#
#     it 'should be initialized like all SexpProcessors' do
#       # less than ideal means of insuring the Flog instance was initialized properly, imo -RB
#       @flog.context.must_equal []
#     end
#
#     it 'should have no current class' do
#       @flog.klass_name.must_equal :main
#     end
#
#     it 'should have no current method' do
#       @flog.method_name.must_equal :none
#     end
#
#     it 'should not have any calls yet' do
#       @flog.calls.must_equal({})
#     end
#
#     it 'should have a means of accessing its parse tree' do
#       @flog.must_respond_to(:parse_tree)
#     end
#
#     it 'should not have any totals yet' do
#       @flog.totals.must_equal({})
#     end
#
#     it 'should have a 0 total score' do
#       @flog.total.must_equal 0.0
#     end
#
#     it 'should have a multiplier of 1' do
#       @flog.multiplier.must_equal 1.0
#     end
#
#     currently "should have 'auto shift type' set to true" do
#       @flog.auto_shift_type.must_equal true
#     end
#
#     currently "should have 'require empty' set to false" do
#       @flog.require_empty.must_equal false
#     end
#   end
#
#   describe 'options' do
#     it 'should return the current options settings' do
#       @flog.must_respond_to(:options)
#     end
#   end
#
#   describe 'when accessing the parse tree' do
#     before :each do
#       @parse_tree = stub('parse tree')
#     end
#
#     describe 'for the first time' do
#       it 'should create a new ParseTree' do
#         RubyParser.expects(:new)
#         @flog.parse_tree
#       end
#
# # HACK: most tarded spec ever
# #       it 'should return a ParseTree instance' do
# #         ParseTree.stubs(:new).returns(@parse_tree)
# #         @flog.parse_tree.must_equal @parse_tree
# #       end
#     end
#
# # HACK Jesus... this is useless.
# #     describe 'after the parse tree has been initialized' do
# #       it 'should not attempt to create a new ParseTree instance' do
# #         @flog.parse_tree
# #         ParseTree.expects(:new).never
# #         @flog.parse_tree
# #       end
# #
# #       it 'should return a ParseTree instance' do
# #         ParseTree.stubs(:new).returns(@parse_tree)
# #         @flog.parse_tree
# #         @flog.parse_tree.must_equal @parse_tree
# #       end
# #     end
#   end
#
#   describe "when flogging a list of files" do
#     describe 'when no files are specified' do
#       currently 'should not raise an exception' do
#         lambda { @flog.flog_files }.wont_raise_error
#       end
#
#       it 'should never call flog_file' do
#         def @flog.flog_file(*args); raise "no"; end
#         @flog.flog_files
#       end
#     end
#
# # HACK
# #     describe 'when files are specified' do
# #       before :each do
# #         @files = [1, 2, 3, 4]
# #         @flog.stubs(:flog_file)
# #       end
# #
# #       it 'should do a flog for each individual file' do
# #         @flog.expects(:flog_file).times(@files.size)
# #         @flog.flog_files(@files)
# #       end
# #
# #       it 'should provide the filename when flogging a file' do
# #         @files.each do |file|
# #           @flog.expects(:flog_file).with(file)
# #         end
# #         @flog.flog_files(@files)
# #       end
# #     end
#
#     describe 'when flogging a single file' do
#       before :each do
#         @flog.stubs(:flog)
#       end
#
#       describe 'when the filename is "-"' do
#         before :each do
#           @stdin = $stdin  # HERE: working through the fact that zenspider is using $stdin in the middle of the system
#           $stdin = stub('stdin', :read => 'data')
#         end
#
#         after :each do
#           $stdin = @stdin
#         end
#
# #         describe 'when reporting blame information' do
# #           before :each do
# #             @flog = Flog.new(:blame => true)
# #             @flog.stubs(:flog)
# #           end
# #
# #           it 'should fail' do
# #             lambda { @flog.flog_file('-') }.must_raise(RuntimeError)
# #           end
# #         end
#
# # HACK: need to figure out how to do nested setup w/o inherited tests
# #         it 'should not raise an exception' do
# #           lambda { @flog.flog_file('-') }.wont_raise_error
# #         end
#
# # HACK: need to figure out how to do nested setup w/o inherited tests
# #         it 'should read the data from stdin' do
# #           $stdin.expects(:read).returns('data')
# #           @flog.flog_file('-')
# #         end
#
# #         it 'should flog the read data' do
# #           @flog.expects(:flog).with('data', '-')
# #           @flog.flog_file('-')
# #         end
#
#         describe 'when the verbose flag is on' do
#           before :each do
#             @flog = Flog.new(:verbose => true)
#           end
#
# #           it 'should note which file is being flogged' do
# #             @flog.expects(:warn)
# #             @flog.flog_file('-')
# #           end
#         end
#
#         describe 'when the verbose flag is off' do
#           before :each do
#             @flog = Flog.new({})
#           end
#
#           it 'should not note which file is being flogged' do
#             def @flog.warn(*args); raise "no"; end
#             @flog.flog_file('-')
#           end
#         end
#       end
#
#       describe 'when the filename points to a directory' do
#         before :each do
#           def @flog.flog_directory(*args); end
#           @file = File.dirname(__FILE__)
#         end
#
#         it 'should expand the files under the directory' do
#           @flog.expects(:flog_directory)
#           @flog.flog_file(@file)
#         end
#
#         it 'should not read data from stdin' do
#           def $stdin.read(*args); raise "no"; end
#           @flog.flog_file(@file)
#         end
#
#         it 'should not flog any data' do
#           def @flog.flog(*args); raise "no"; end
#           @flog.flog_file(@file)
#         end
#       end
#
#       describe 'when the filename points to a non-existant file' do
#         before :each do
#           @file = '/adfasdfasfas/fasdfaf-#{rand(1000000).to_s}'
#         end
#
#         it 'should raise an exception' do
#           lambda { @flog.flog_file(@file) }.must_raise(Errno::ENOENT)
#         end
#       end
#
# #       describe 'when the filename points to an existing file' do
# #         before :each do
# #           @file = __FILE__
# #           File.stubs(:read).returns('data')
# #         end
# #
# #         it 'should read the contents of the file' do
# #           File.expects(:read).with(@file).returns('data')
# #           @flog.flog_file(@file)
# #         end
# #
# #         it 'should flog the contents of the file' do
# #           @flog.expects(:flog).with('data', @file)
# #           @flog.flog_file(@file)
# #         end
# #
# #         describe 'when the verbose flag is on' do
# #           before :each do
# #             @flog = Flog.new(:verbose => true)
# #           end
# #
# #           it 'should note which file is being flogged' do
# #             @flog.expects(:warn)
# #             @flog.flog_file(@file)
# #           end
# #         end
# #
# #         describe 'when the verbose flag is off' do
# #           before :each do
# #             @flog = Flog.new({})
# #           end
# #
# #           it 'should not note which file is being flogged' do
# #             def @flog.warn(*args); raise "no"; end
# #             @flog.flog_file(@file)
# #           end
# #         end
# #       end
#     end
#   end
#
# #   describe 'when flogging a directory' do
# #     before :each do
# #       @files = ['a.rb', '/foo/b.rb', '/foo/bar/c.rb', '/foo/bar/baz/d.rb']
# #       @dir = File.dirname(__FILE__)
# #       Dir.stubs(:[]).returns(@files)
# #     end
# #
# #     it 'should get the list of ruby files under the directory' do
# #       @flog.stubs(:flog_file)
# #       Dir.expects(:[]).returns(@files)
# #       @flog.flog_directory(@dir)
# #     end
# #
# #     it "should call flog_file once for each file in the directory" do
# #       @files.each {|f| @flog.expects(:flog_file).with(f) }
# #       @flog.flog_directory(@dir)
# #     end
# #   end
#
#   describe 'when flogging a Ruby string' do
#     it 'should require both a Ruby string and a filename' do
#       lambda { @flog.flog('string') }.must_raise(ArgumentError)
#     end
#
#     describe 'when reporting blame information' do
#       before :each do
#         @flog = Flog.new(:blame => true)
#       end
#
#       it 'should gather blame information for the file' do
#         @flog.expects(:collect_blame).with('filename')
#         @flog.flog('string', 'filename')
#       end
#     end
#
#     describe 'when not reporting blame information' do
#       it 'should not gather blame information for the file' do
#         def @flog.collect_blame(*args); raise "no"; end
#         @flog.flog('string', 'filename')
#       end
#     end
#
#     describe 'when the string has a syntax error' do
#       before :each do
#         def @flog.warn(*args); end
#         def @flog.process_parse_tree(*args); raise SyntaxError, "<% foo %>"; end
#       end
#
#       describe 'when the string has erb snippets' do
#         currently 'should warn about skipping' do
#           @flog.expects(:warn)
#           @flog.flog('string', 'filename')
#         end
#
#         it 'should not raise an exception' do
#           lambda { @flog.flog('string', 'filename') }.wont_raise_error
#         end
#
#         it 'should not process the failing code' do
#           def @flog.process(*args); raise "no"; end
#           @flog.flog('string', 'filename')
#         end
#       end
#
#       describe 'when the string has no erb snippets' do
#         before :each do
#           def @flog.process_parse_tree(*args); raise SyntaxError; end
#         end
#
#         it 'should raise a SyntaxError exception' do
#           # TODO: what the fuck?!? how does this test ANYTHING?
#           # it checks that #flog calls #process_parse_tree?? AND?!?!
#           lambda { @flog.flog('string', 'filename') }.must_raise(SyntaxError)
#         end
#
#         it 'should not process the failing code' do
#           def @flog.process(*args); raise "no"; end
#           lambda { @flog.flog('string', 'filename') }
#         end
#       end
#     end
#
#     describe 'when the string contains valid Ruby' do
#       before :each do
#         @flog.stubs(:process_parse_tree)
#       end
#
#       it 'should process the parse tree for the string' do
#         @flog.expects(:process_parse_tree)
#         @flog.flog('string', 'filename')
#       end
#
#       it 'should provide the string and the filename to the parse tree processor' do
#         @flog.expects(:process_parse_tree).with('string', 'filename')
#         @flog.flog('string', 'filename')
#       end
#     end
#   end
#
# #   describe 'when processing a ruby parse tree' do
# #     before :each do
# #       @flog.stubs(:process)
# #       @sexp = stub('s-expressions')
# #       @parse_tree = stub('parse tree', :parse_tree_for_string => @sexp)
# #       ParseTree.stubs(:new).returns(@parse_tree)
# #     end
# #
# #     it 'should require both a ruby string and a filename' do
# #       lambda { @flog.process_parse_tree('string') }.must_raise(ArgumentError)
# #     end
# #
# #     it 'should compute the parse tree for the ruby string' do
# #       Sexp.stubs(:from_array).returns(['1', '2'])
# #       @parse_tree.expects(:parse_tree_for_string).returns(@sexp)
# #       @flog.process_parse_tree('string', 'file')
# #     end
# #
# #     it 'should use both the ruby string and the filename when computing the parse tree' do
# #       Sexp.stubs(:from_array).returns(['1', '2'])
# #       @parse_tree.expects(:parse_tree_for_string).with('string', 'file').returns(@sexp)
# #       @flog.process_parse_tree('string', 'file')
# #     end
# #
# #     describe 'if the ruby string is valid' do
# #       before :each do
# #         $pt = @parse_tree = stub('parse tree', :parse_tree_for_string => @sexp)
# #         def @flog.process; end
# #         def @flog.parse_tree; return $pt; end
# #       end
# #
# #       it 'should convert the parse tree into a list of S-expressions' do
# #         Sexp.expects(:from_array).with(@sexp).returns(['1', '2'])
# #         @flog.process_parse_tree('string', 'file')
# #       end
# #
# #       it 'should process the list of S-expressions' do
# #         @flog.expects(:process)
# #         @flog.process_parse_tree('string', 'file')
# #       end
# #
# #       it 'should start processing at the first S-expression' do
# #         Sexp.stubs(:from_array).returns(['1', '2'])
# #         @flog.expects(:process).with('1')
# #         @flog.process_parse_tree('string', 'file')
# #       end
# #     end
# #
# #     describe 'if the ruby string is invalid' do
# #       before :each do
# #         $parse_tree = stub('parse tree')
# #         def @flog.parse_tree; return $parse_tree; end
# #         def $parse_tree.parse_tree_for_string(*args); raise SyntaxError; end
# #       end
# #
# #       it 'should fail' do
# #         lambda { @flog.process_parse_tree('string', 'file') }.must_raise(SyntaxError)
# #       end
# #
# #       it 'should not attempt to process the parse tree' do
# #         def @flog.process(*args); raise "no"; end
# #         lambda { @flog.process_parse_tree('string', 'file') }
# #       end
# #     end
# #   end
#
#   describe 'when collecting blame information from a file' do
#     it 'should require a filename' do
#       lambda { @flog.collect_blame }.must_raise(ArgumentError)
#     end
#
#     it 'should not fail when given a filename' do
#       @flog.collect_blame('filename')
#     end
#
#     # TODO: talk to Rick and see what he was planning for
#     # this... otherwise I'm thinking it should be ripped out
#
#     # it 'should have more specs'
#   end
#
#   describe 'multiplier' do
#     it 'should be possible to determine the current value of the multiplier' do
#       @flog.must_respond_to(:multiplier)
#     end
#
#     currently 'should be possible to set the current value of the multiplier' do
#       @flog.multiplier = 10
#       @flog.multiplier.must_equal 10
#     end
#   end
#
#   describe 'class_stack' do
#     it 'should be possible to determine the current value of the class stack' do
#       @flog.must_respond_to(:class_stack)
#     end
#
#     currently 'should be possible to set the current value of the class stack' do
#       @flog.class_stack << 'name'
#       @flog.class_stack.must_equal [ 'name' ]
#     end
#   end
#
#   describe 'method_stack' do
#     it 'should be possible to determine the current value of the method stack' do
#       @flog.must_respond_to(:method_stack)
#     end
#
#     currently 'should be possible to set the current value of the method stack' do
#       @flog.method_stack << 'name'
#       @flog.method_stack.must_equal [ 'name' ]
#     end
#   end
#
#   describe 'when adding to the current flog score' do
#     before :each do
#       @flog.multiplier = 1
#       def @flog.klass_name; return 'foo'; end
#       def @flog.method_name; return 'bar'; end
#       @flog.calls['foo#bar'] = { :alias => 0 }
#     end
#
#     it 'should require an operation name' do
#       lambda { @flog.add_to_score() }.must_raise(ArgumentError)
#     end
#
#     it 'should update the score for the current class, method, and operation' do
#       @flog.add_to_score(:alias)
#       @flog.calls['foo#bar'][:alias].wont_equal 0
#     end
#
#     it 'should use the multiplier when updating the current call score' do
#       @flog.multiplier = 10
#       @flog.add_to_score(:alias)
#       @flog.calls['foo#bar'][:alias].must_equal 10*Flog::OTHER_SCORES[:alias]
#     end
#   end
#
#   describe 'when computing the average per-call flog score' do
#     it 'should not allow arguments' do
#       lambda { @flog.average('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should return the total flog score divided by the number of calls' do
#       def @flog.total; return 100; end
#       def @flog.calls; return :bar => {}, :foo => {} ; end
#       @flog.average.must_be_close_to 50.0
#     end
#   end
#
#   describe 'when recursively analyzing the complexity of code' do
#     it 'should require a complexity modifier value' do
#       lambda { @flog.penalize_by }.must_raise(ArgumentError)
#     end
#
#     it 'should require a block, for code to recursively analyze' do
#       lambda { @flog.penalize_by(42) }.must_raise(LocalJumpError)
#     end
#
#     it 'should recursively analyze the provided code block' do
#       @flog.penalize_by(42) do
#         @foo = true
#       end
#
#       @foo.must_equal true
#     end
#
#     it 'should update the complexity multiplier when recursing' do
#       @flog.multiplier = 1
#       @flog.penalize_by(42) do
#         @flog.multiplier.must_equal 43
#       end
#     end
#
#     it 'when it is done it should restore the complexity multiplier to its original value' do
#       @flog.multiplier = 1
#       @flog.penalize_by(42) do
#       end
#       @flog.multiplier.must_equal 1
#     end
#   end
#
#   describe 'when computing complexity of all remaining opcodes' do
#     it 'should require a list of opcodes' do
#       lambda { @flog.analyze_list }.must_raise(ArgumentError)
#     end
#
# # HACK: nope. this is just poorly written.
# #     it 'should process each opcode' do
# #       @opcodes = [ :foo, :bar, :baz ]
# #       @opcodes.each do |opcode|
# #          @flog.expects(:process).with(opcode)
# #       end
# #
# #       @flog.analyze_list @opcodes
# #     end
#   end
#
#   describe 'when recording the current class being analyzed' do
#     it 'should require a class name' do
#       lambda { @flog.in_klass }.must_raise(ArgumentError)
#     end
#
#     it 'should require a block during which the class name is in effect' do
#       lambda { @flog.in_klass('name') }.must_raise(LocalJumpError)
#     end
#
#     it 'should recursively analyze the provided code block' do
#       @flog.in_klass 'name' do
#         @foo = true
#       end
#
#       @foo.must_equal true
#     end
#
#     it 'should update the class stack when recursing' do
#       @flog.class_stack.clear
#       @flog.in_klass 'name' do
#         @flog.class_stack.must_equal ['name']
#       end
#     end
#
#     it 'when it is done it should restore the class stack to its original value' do
#       @flog.class_stack.clear
#       @flog.in_klass 'name' do
#       end
#       @flog.class_stack.must_equal []
#     end
#   end
#
#   describe 'when looking up the name of the class currently under analysis' do
#     it 'should not take any arguments' do
#       lambda { @flog.klass_name('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should return the most recent class entered' do
#       @flog.class_stack << :foo << :bar << :baz
#       @flog.klass_name.must_equal :foo
#     end
#
#     it 'should return the default class if no classes entered' do
#       @flog.class_stack.clear
#       @flog.klass_name.must_equal :main
#     end
#   end
#
#   describe 'when recording the current method being analyzed' do
#     it 'should require a method name' do
#       lambda { @flog.in_method }.must_raise(ArgumentError)
#     end
#
#     it 'should require a block during which the class name is in effect' do
#       lambda { @flog.in_method('name') }.must_raise(LocalJumpError)
#     end
#
#     it 'should recursively analyze the provided code block' do
#       @flog.in_method 'name' do
#         @foo = true
#       end
#
#       @foo.must_equal true
#     end
#
#     it 'should update the class stack when recursing' do
#       @flog.method_stack.clear
#       @flog.in_method 'name' do
#         @flog.method_stack.must_equal ['name']
#       end
#     end
#
#     it 'when it is done it should restore the class stack to its original value' do
#       @flog.method_stack.clear
#       @flog.in_method 'name' do
#       end
#       @flog.method_stack.must_equal []
#     end
#   end
#
#   describe 'when looking up the name of the method currently under analysis' do
#     it 'should not take any arguments' do
#       lambda { @flog.method_name('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should return the most recent method entered' do
#       @flog.method_stack << :foo << :bar << :baz
#       @flog.method_name.must_equal :foo
#     end
#
#     it 'should return the default method if no methods entered' do
#       @flog.method_stack.clear
#       @flog.method_name.must_equal :none
#     end
#   end
#
#   describe 'when resetting state' do
#     it 'should not take any arguments' do
#       lambda { @flog.reset('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should clear any recorded totals data' do
#       @flog.totals['foo'] = 'bar'
#       @flog.reset
#       @flog.totals.must_equal({})
#     end
#
#     it 'should clear the total score' do
#       # the only way I know to do this is to force the total score to be computed for actual code, then reset it
#       @flog.flog_files(fixture_files('/simple/simple.rb'))
#       @flog.reset
#       @flog.total.must_equal 0
#     end
#
#     it 'should set the multiplier to 1.0' do
#       @flog.multiplier = 20.0
#       @flog.reset
#       @flog.multiplier.must_equal 1.0
#     end
#
#     it 'should set clear any calls data' do
#       @flog.calls['foobar'] = 'yoda'
#       @flog.reset
#       @flog.calls.must_equal({})
#     end
#
#     it 'should ensure that new recorded calls will get 0 counts without explicit initialization' do
#       @flog.reset
#       @flog.calls['foobar']['baz'] += 20
#       @flog.calls['foobar']['baz'].must_equal 20
#     end
#   end
#
#   describe 'when retrieving the total score' do
#     it 'should take no arguments' do
#       lambda { @flog.total('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should return 0 if nothing has been analyzed' do
#       @flog.total.must_equal 0
#     end
#
#     it 'should compute totals data when called the first time' do
#       @flog.expects(:totals)
#       @flog.total
#     end
#
#     it 'should not recompute totals data when called after the first time' do
#       @flog.total
#       def @flog.totals(*args); raise "no"; end
#       @flog.total
#     end
#
#     it 'should return the score from the analysis once files have been analyzed' do
#       @flog.flog_files(fixture_files('/simple/simple.rb'))
#       @flog.total.wont_equal 0
#     end
#   end
#
#   describe 'when computing a score for a method' do
#     it 'should require a hash of call tallies' do
#       lambda { @flog.score_method }.must_raise(ArgumentError)
#     end
#
#     it 'should return a score of 0 if no tallies are provided' do
#       @flog.score_method({}).must_equal 0.0
#     end
#
#     it 'should compute the sqrt of summed squares for assignments, branches, and other tallies' do
#       @flog.score_method({
#         :assignment => 7,
#         :branch => 23,
#         :crap => 37
#       }).must_be_close_to Math.sqrt(7*7 + 23*23 + 37*37)
#     end
#   end
#
#   describe 'when recording a total for a method' do
#     # guess what, @totals and @calls could be refactored to be first-class objects
#     it 'should require a method and a score' do
#       lambda { @flog.record_method_score('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should set the total score for the provided method' do
#       @flog.record_method_score('foo', 20)
#       @flog.totals['foo'].must_equal 20
#     end
#   end
#
#   describe 'when updating the total flog score' do
#     it 'should require an amount to update by' do
#       lambda { @flog.increment_total_score_by }.must_raise(ArgumentError)
#     end
#
#     it 'should update the total flog score' do
#       @flog.total_score = 0
#       @flog.increment_total_score_by 42
#       @flog.total.must_equal 42
#     end
#   end
#
#   describe 'when compiling summaries for a method' do
#     before :each do
#       @tally = { :foo => 0.0 }
#       @method = 'foo'
#       $score = @score = 42.0
#
#       @flog.total_score = 0
#
#       def @flog.score_method(*args); return $score; end
#       def @flog.record_method_score(*args); end
#       def @flog.increment_total_score_by(*args); end
#     end
#
#     it 'should require a method name and a tally' do
#       lambda { @flog.summarize_method('foo') }.must_raise(ArgumentError)
#     end
#
#     it 'should compute a score for the method, based on the tally' do
#       @flog.expects(:score_method).with(@tally)
#       @flog.summarize_method(@method, @tally)
#     end
#
#     it 'should record the score for the method' do
#       @flog.expects(:record_method_score).with(@method, @score)
#       @flog.summarize_method(@method, @tally)
#     end
#
#     it 'should update the overall flog score' do
#       @flog.expects(:increment_total_score_by).with(@score)
#       @flog.summarize_method(@method, @tally)
#     end
#
# # HACK: I don't see how these ever worked if the above passes... *shrug*
# #     describe 'ignoring non-method code and given a non-method tally' do
# #       it 'should not compute a score for the tally' do
# #         def @flog.score_method(*args); raise "no"; end
# #         @flog.summarize_method(@method, @tally)
# #       end
# #
# #       it 'should not record a score based on the tally' do
# #         def @flog.record_method_score(*args); raise "no"; end
# #         @flog.summarize_method(@method, @tally)
# #       end
# #
# #       it 'should not update the overall flog score' do
# #         def @flog.increment_total_score_by(*args); raise "no"; end
# #         @flog.summarize_method(@method, @tally)
# #       end
# #     end
#   end
#
#   describe 'when requesting totals' do
#     it 'should not accept any arguments' do
#       lambda { @flog.totals('foo') }.must_raise(ArgumentError)
#     end
#
#     describe 'when called the first time' do
# #       it 'should access calls data' do
# #         @flog.expects(:calls).returns({})
# #         @flog.totals
# #       end
#
# #       it "will compile a summary for each method from the method's tally" do
# #         $calls = @calls = { :foo => 1.0, :bar => 2.0, :baz => 3.0 }
# #         def @flog.calls; return $calls; end
# #
# #         @calls.each do |meth, tally|
# #           @flog.expects(:summarize_method).with(meth, tally)
# #         end
# #
# #         @flog.totals
# #       end
#
#       it 'should return the totals data' do
#         @flog.totals.must_equal({})
#       end
#     end
#
#     describe 'when called after the first time' do
#       before :each do
#         @flog.totals
#       end
#
#       it 'should not access calls data' do
#         def @flog.calls(*args); raise "no"; end
#         @flog.totals
#       end
#
#       it 'should not compile method summaries' do
#         def @flog.summarize_method(*args); raise "no"; end
#         @flog.totals
#       end
#
#       it 'should return the totals data' do
#         @flog.totals.must_equal({})
#       end
#     end
#   end
#
#   describe 'when producing a report summary' do
#     before :each do
#       @handle = stub('io handle)', :puts => nil)
#       @total_score = 42.0
#       @average_score = 1.0
#       def @flog.total; return 42.0; end
#       def @flog.average; return 1.0; end
#     end
#
#     it 'should require an io handle' do
#       lambda { @flog.output_summary }.must_raise(ArgumentError)
#     end
#
#     it 'computes the total flog score' do
#       # HACK @flog.expects(:total).returns 42.0
#       @flog.output_summary(@handle)
#     end
#
#     it 'computes the average flog score' do
#       # HACK @flog.expects(:average).returns 1.0
#       @flog.output_summary(@handle)
#     end
#
#     it 'outputs the total flog score to the handle' do
#       @handle.expects(:puts).with do |string|
#         string =~ Regexp.new(Regexp.escape("%.1f" % @total_score))
#       end
#       @flog.output_summary(@handle)
#     end
#
#     it 'outputs the average flog score to the handle' do
#       @handle.expects(:puts).with do |string|
#         string =~ Regexp.new(Regexp.escape("%.1f" % @average_score))
#       end
#       @flog.output_summary(@handle)
#     end
#   end
#
#   describe 'when producing a detailed call summary report' do
#     before :each do
#       @handle = stub('io handle)', :puts => nil)
#       $calls = @calls = { :foo => {}, :bar => {}, :baz => {} }
#       $totals = @totals = { :foo => 1, :bar => 2, :baz => 3 }
#
#       def @flog.calls; return $calls; end
#       def @flog.totals; return $totals; end
#       def @flog.output_method_details(*args); return 5; end
#     end
#
#     it 'should require an i/o handle' do
#       lambda { @flog.output_details }.must_raise(ArgumentError)
#     end
#
#     it 'should allow a threshold on the amount of detail to report' do
#       lambda { @flog.output_details(@handle, 300) }.wont_raise_error(ArgumentError)
#     end
#
# #     it 'retrieves the set of total statistics' do
# #       @flog.expects(:totals).returns(@totals)
# #       @flog.output_details(@handle)
# #     end
#
# #     it 'retrieves the set of call statistics' do
# #       @flog.expects(:calls).returns({})
# #       @flog.output_details(@handle)
# #     end
#
# #     it 'should output a method summary for each located method' do
# #       @calls.each do |meth, list|
# #         @flog.expects(:output_method_details).with(@handle, meth, list).returns(5)
# #       end
# #       @flog.output_details(@handle)
# #     end
# #
# #     describe 'if a threshold is provided' do
# #       it 'should only output details for methods until the threshold is reached' do
# #         @flog.expects(:output_method_details).with(@handle, :baz, {}).returns(5)
# #         @flog.expects(:output_method_details).with(@handle, :bar, {}).returns(5)
# #         # HACK @flog.expects(:output_method_details).with(@handle, :foo, {}).never
# #         @flog.output_details(@handle, 10)
# #       end
# #     end
#
# #     describe 'if no threshold is provided' do
# #       it 'should output details for all methods' do
# #         @calls.each do |class_method, call_list|
# #           @flog.expects(:output_method_details).with(@handle, class_method, call_list).returns(5)
# #         end
# #         @flog.output_details(@handle)
# #       end
# #     end
#   end
#
#   describe 'when reporting the details for a specific method' do
#     before :each do
#       @handle = stub('i/o handle', :puts => nil)
#       $totals = { 'foo#foo' => 42.0, 'foo#none' => 12.0 }
#       @data = { :assign => 10, :branch => 5, :case => 3 }
#       def @flog.totals; return $totals; end
#     end
#
#     it 'should require an i/o handle, a method name, and method details' do
#       lambda { @flog.output_method_details('foo', 'bar') }.must_raise(ArgumentError)
#     end
#
#     describe 'and ignoring non-method code' do
#       before :each do
#         @flog = Flog.new(:methods => true)
#         def @flog.totals; return $totals; end
#       end
#
#       describe 'and given non-method data to summarize' do
#         it 'should not generate any output on the i/o handle' do
#           def @handle.puts(*args); raise "no"; end
#           @flog.output_method_details(@handle, 'foo#none', @data)
#         end
#
#         it 'should return 0' do
#           @flog.output_method_details(@handle, 'foo#none', @data).must_equal 0.0
#         end
#       end
#
#       describe 'and given method data to summarize' do
#         it 'should return the total complexity for the method' do
#           @flog.output_method_details(@handle, 'foo#foo', @data).must_equal 42.0
#         end
#
#         it 'should output the overall total for the method' do
#           @handle.expects(:puts).with do |string|
#             string =~ Regexp.new(Regexp.escape("%.1f" % 42.0))
#           end
#           @flog.output_method_details(@handle, 'foo#foo', @data)
#         end
#
#         it 'should output call details for each call for the method' do
#           @data.each do |call, count|
#             @handle.expects(:puts).with do |string|
#               string =~ Regexp.new(Regexp.escape("%6.1f: %s" % [ count, call ]))
#             end
#           end
#           @flog.output_method_details(@handle, 'foo#foo', @data)
#         end
#       end
#     end
#
#     describe 'and not excluding non-method code' do
#       it 'should return the total complexity for the method' do
#         @flog.output_method_details(@handle, 'foo#foo', @data).must_equal 42.0
#       end
#
#       it 'should output the overall total for the method' do
#         @handle.expects(:puts).with do |string|
#           string =~ Regexp.new(Regexp.escape("%.1f" % 42.0))
#         end
#         @flog.output_method_details(@handle, 'foo#foo', @data)
#       end
#
#       it 'should output call details for each call for the method' do
#         @data.each do |call, count|
#           @handle.expects(:puts).with do |string|
#             string =~ Regexp.new(Regexp.escape("%6.1f: %s" % [ count, call ]))
#           end
#         end
#         @flog.output_method_details(@handle, 'foo#foo', @data)
#       end
#     end
#   end
#
#   describe 'when generating a report' do
#     before :each do
#       @flog.stubs(:output_summary)
#       @handle = stub('io handle)', :puts => nil)
#     end
#
# #     it 'allows specifying an i/o handle' do
# #       lambda { @flog.report @handle }.wont_raise_error(ArgumentError)
# #     end
# #
# #     it 'allows running the report without a specified i/o handle' do
# #       lambda { @flog.report }.wont_raise_error(ArgumentError)
# #     end
#
# #     describe 'and no i/o handle is specified' do
# #       it 'defaults the io handle to stdout' do
# #         @flog.expects(:output_summary).with($stdout)
# #         @flog.report
# #       end
# #     end
#
#     describe 'and producing a summary report' do
#       before :each do
#         @flog = Flog.new(:score => true)
#         @flog.stubs(:output_summary)
#       end
#
#       it 'produces an output summary on the i/o handle' do
#         @flog.expects(:output_summary).with(@handle)
#         @flog.report(@handle)
#       end
#
#       it 'does not output a detailed report' do
#         def @flog.output_details(*args); raise "no"; end
#         @flog.report(@handle)
#       end
#
#       it 'should reset statistics when finished' do
#         @flog.expects(:reset)
#         @flog.report(@handle)
#       end
#     end
#
#     describe 'and producing a full report' do
#       before :each do
#         @flog.stubs(:output_summary)
#         @flog.stubs(:output_details)
#       end
#
#       it 'produces an output summary on the i/o handle' do
#         @flog.expects(:output_summary).with(@handle)
#         @flog.report(@handle)
#       end
#
#       it 'should generate a detailed report of method complexity on the i/o handle' do
#         @flog.expects(:output_details).with {|handle, max| handle == @handle }
#         @flog.report(@handle)
#       end
#
#       describe 'when flogging all methods in the system' do
#         before :each do
#           @flog = Flog.new(:all => true)
#           @flog.stubs(:output_summary)
#           @flog.stubs(:output_details)
#         end
#
#         it 'should not limit the detailed report' do
#           @flog.expects(:output_details).with(@handle)
#           @flog.report(@handle)
#         end
#       end
#
#       describe 'when flogging only the most expensive methods in the system' do
#         it 'should limit the detailed report to the Flog threshold' do
#           def @flog.total; return 3.45; end
#           @flog.expects(:output_details).with(@handle, 3.45 * 0.60)
#           @flog.report(@handle)
#         end
#       end
#
#       it 'should reset statistics when finished' do
#         @flog.expects(:reset)
#         @flog.report(@handle)
#       end
#     end
#   end
# end

############################################################
# TODO after driver code is covered

#   def test_process_alias
#     raise NotImplementedError, 'Need to write test_process_alias'
#   end
#
#   def test_process_and
#     raise NotImplementedError, 'Need to write test_process_and'
#   end
#
#   def test_process_attrasgn
#     raise NotImplementedError, 'Need to write test_process_attrasgn'
#   end
#
#   def test_process_attrset
#     raise NotImplementedError, 'Need to write test_process_attrset'
#   end
#
#   def test_process_block
#     raise NotImplementedError, 'Need to write test_process_block'
#   end
#
#   def test_process_block_pass
#     raise NotImplementedError, 'Need to write test_process_block_pass'
#   end
#
#   def test_process_call
#     raise NotImplementedError, 'Need to write test_process_call'
#   end
#
#   def test_process_case
#     raise NotImplementedError, 'Need to write test_process_case'
#   end
#
#   def test_process_class
#     raise NotImplementedError, 'Need to write test_process_class'
#   end
#
#   def test_process_dasgn_curr
#     raise NotImplementedError, 'Need to write test_process_dasgn_curr'
#   end
#
#   def test_process_defn
#     raise NotImplementedError, 'Need to write test_process_defn'
#   end
#
#   def test_process_defs
#     raise NotImplementedError, 'Need to write test_process_defs'
#   end
#
#   def test_process_else
#     raise NotImplementedError, 'Need to write test_process_else'
#   end
#
#   def test_process_iasgn
#     raise NotImplementedError, 'Need to write test_process_iasgn'
#   end
#
#   def test_process_if
#     raise NotImplementedError, 'Need to write test_process_if'
#   end
#
#   def test_process_iter
#     raise NotImplementedError, 'Need to write test_process_iter'
#   end
#
#   def test_process_lasgn
#     raise NotImplementedError, 'Need to write test_process_lasgn'
#   end
#
#   def test_process_lit
#     raise NotImplementedError, 'Need to write test_process_lit'
#   end
#
#   def test_process_masgn
#     raise NotImplementedError, 'Need to write test_process_masgn'
#   end
#
#   def test_process_module
#     raise NotImplementedError, 'Need to write test_process_module'
#   end
#
#   def test_process_or
#     raise NotImplementedError, 'Need to write test_process_or'
#   end
#
#   def test_process_parse_tree
#     raise NotImplementedError, 'Need to write test_process_parse_tree'
#   end
#
#   def test_process_rescue
#     raise NotImplementedError, 'Need to write test_process_rescue'
#   end
#
#   def test_process_sclass
#     raise NotImplementedError, 'Need to write test_process_sclass'
#   end
#
#   def test_process_super
#     raise NotImplementedError, 'Need to write test_process_super'
#   end
#
#   def test_process_until
#     raise NotImplementedError, 'Need to write test_process_until'
#   end
#
#   def test_process_when
#     raise NotImplementedError, 'Need to write test_process_when'
#   end
#
#   def test_process_while
#     raise NotImplementedError, 'Need to write test_process_while'
#   end
#
#   def test_process_yield
#     raise NotImplementedError, 'Need to write test_process_yield'
#   end
#
