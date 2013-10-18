require "test/test_flog"
require "flog_cli"

class FlogCLI
  def_delegators :@flog, :totals # FIX: test_report_all is overreaching?
  def_delegators :@flog, :calls  # FIX: refactor?
  def_delegators :@flog, :mass   # FIX: refactor?
end

class TestFlogCLI < FlogTest
  def setup
    @flog = FlogCLI.new :parser => RubyParser
  end

  def test_cls_expand_dirs_to_files
    expected = %w(lib/flog.rb lib/flog_cli.rb lib/flog_task.rb lib/gauntlet_flog.rb)
    assert_equal expected, FlogCLI.expand_dirs_to_files('lib')
    expected = %w(Rakefile)
    assert_equal expected, FlogCLI.expand_dirs_to_files('Rakefile')
  end

  def test_cls_parse_options
    # defaults
    opts = FlogCLI.parse_options
    assert_equal false,  opts[:quiet]
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
      "-e"             => :extended,
      "--extended"     => :extended,
      "-s"             => :score,
      "--score"        => :score,
      "-v"             => :verbose,
      "--verbose"      => :verbose,
    }.each do |key, val|
      assert_equal true, FlogCLI.parse_options(key)[val]
    end
  end

  def test_cls_parse_options_path
    old_path = $:.dup
    FlogCLI.parse_options("-Ia,b,c")
    assert_equal old_path + %w(a b c), $:

    FlogCLI.parse_options(["-I", "d,e,f"])
    assert_equal old_path + %w(a b c d e f), $:

    FlogCLI.parse_options(["-I", "g", "-Ih"])
    assert_equal old_path + %w(a b c d e f g h), $:
  ensure
    $:.replace old_path
  end

  def test_cls_parse_options_help
    def FlogCLI.exit
      raise "happy"
    end

    ex = nil
    o, e = capture_io do
      ex = assert_raises RuntimeError do
        FlogCLI.parse_options "-h"
      end
    end

    assert_equal "happy", ex.message
    assert_match(/methods-only/, o)
    assert_equal "", e
  end

  def test_output_details
    @flog.option[:all] = true
    setup_flog

    o = StringIO.new
    @flog.output_details o

    expected = "\n     1.6: main#none\n"

    assert_equal expected, o.string
    assert_equal 1.6, @flog.totals["main#none"]
  end

  def test_output_details_grouped
    setup_flog

    o = StringIO.new
    @flog.calculate_total_scores
    @flog.output_details_grouped o

    expected = "\n     1.6: main total\n     1.6: main#none\n"

    assert_equal expected, o.string
  end

  def test_output_details_methods
    @flog.option[:methods] = true

    setup_flog

    o = StringIO.new
    @flog.output_details o

    # HACK assert_equal "", o.string
    assert_equal 0, @flog.totals["main#none"]
  end

  def test_output_details_detailed
    @flog.option[:details] = true

    setup_flog

    o = StringIO.new
    @flog.output_details o, nil

    expected = "\n     1.6: main#none
     1.0:   +
     0.6:   lit_fixnum

"

    assert_equal expected, o.string
    assert_equal 1.6, @flog.totals["main#none"]
  end

  def test_report
    setup_flog

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

    exp = { "main#none" => { :+ => 1.0, :lit_fixnum => 0.6 } }
    assert_equal exp, @flog.calls

    @flog.option[:all] = true
    @flog.calculate_total_scores

    assert_equal 1.6, @flog.total_score unless @flog.option[:methods]
    assert_equal 3, @flog.mass["-"]

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

    setup_flog

    o = StringIO.new
    @flog.report o

    expected = "     1.6: flog total
     1.6: flog/method average

     1.6: main total
     1.6: main#none
"

    assert_equal expected, o.string
  end
end
