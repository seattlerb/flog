require File.dirname(__FILE__) + '/spec_helper.rb'
require 'flog'

describe 'flog command' do
  before :each do
    @flog = stub('Flog', :flog_files => true, :report => true)
    Flog.stubs(:new).returns(@flog)
    self.stubs(:exit)
    self.stubs(:puts)
  end

  def run_command
    eval File.read(File.join(File.dirname(__FILE__), *%w[.. bin flog]))
  end

  describe 'when no command-line arguments are specified' do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = []
    end

    it 'should run' do
      lambda { run_command }.should_not raise_error(Errno::ENOENT)
    end

    it 'should not alter the include path' do
      @paths = $:.dup
      run_command
      $:.should == @paths
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it 'should not have any options flags set' do
      Flog.expects(:new).with({}).returns(@flog)
      run_command
    end

    it 'should call flog_files on the Flog instance' do
      @flog.expects(:flog_files)
      run_command
    end

    it "should pass '-' (for the file path) to flog_files on the instance" do
      @flog.expects(:flog_files).with(['-'])
      run_command
    end

    it 'should call report on the Flog instance' do
      @flog.expects(:report)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -a is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-a']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to show all methods" do
      Flog.expects(:new).with(:all => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --all is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['--all']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to show all methods" do
      Flog.expects(:new).with(:all => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -s is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-s']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to show only the score" do
      Flog.expects(:new).with(:score => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --score is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['--score']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to show only the score" do
      Flog.expects(:new).with(:score => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -m is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-m']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to report on methods only" do
      Flog.expects(:new).with(:methods => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --methods-only is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['--methods-only']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to report on methods only" do
      Flog.expects(:new).with(:methods => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -v is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-v']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to be verbose" do
      Flog.expects(:new).with(:verbose => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --verbose is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['--verbose']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to be verbose" do
      Flog.expects(:new).with(:verbose => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -h is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-h']
    end

    it "should display help information" do
      self.expects(:puts)
      run_command
    end

    it 'should not create a Flog instance' do
      Flog.expects(:new).never
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --help is specified on the command-line" do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['--help']
    end

    it "should display help information" do
      self.expects(:puts)
      run_command
    end

    it 'should not create a Flog instance' do
      Flog.expects(:new).never
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe 'when -I is specified on the command-line' do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-I /tmp,/etc']
    end

    before :each do
      @paths = $:.dup
    end

    it "should append each ':' separated path to $:" do
      run_command
      $:.should_not == @paths
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe 'when -b is specified on the command-line' do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['-b']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to provide 'blame' information" do
      Flog.expects(:new).with(:blame => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe 'when --blame is specified on the command-line' do
    before :each do
      Object.send(:remove_const, :ARGV)
      ARGV = ['--blame']
    end

    it 'should create a Flog instance' do
      Flog.expects(:new).returns(@flog)
      run_command
    end

    it "should set the option to provide 'blame' information" do
      Flog.expects(:new).with(:blame => true).returns(@flog)
      run_command
    end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end
end
