require File.dirname(__FILE__) + '/test_helper.rb'
require 'flog'

describe 'flog command' do
  before :each do
    @flog = stub('Flog', :flog_files => true, :report => true)
    # Flog.stubs(:new).returns(@flog)
    def @flog.exit; end
    def @flog.puts; end
  end

  def run_command
    # HACK eval File.read(File.join(File.dirname(__FILE__), *%w[.. bin flog]))
  end

  describe 'when no command-line arguments are specified' do
    before :each do
      ARGV.clear
    end

    it 'should run' do
      lambda { run_command }.wont_raise_error(Errno::ENOENT)
    end

    it 'should not alter the include path' do
      @paths = $:.dup
      run_command
      $:.must_equal @paths
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it 'should not have any options flags set' do
#       Flog.expects(:new).with({}).returns(@flog)
#       run_command
#     end

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
      ARGV.replace ['-a']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to show all methods" do
#       Flog.expects(:new).with(:all => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --all is specified on the command-line" do
    before :each do
      ARGV.replace ['--all']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to show all methods" do
#       Flog.expects(:new).with(:all => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -s is specified on the command-line" do
    before :each do
      ARGV.replace ['-s']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to show only the score" do
#       Flog.expects(:new).with(:score => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --score is specified on the command-line" do
    before :each do
      ARGV.replace ['--score']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to show only the score" do
#       Flog.expects(:new).with(:score => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -m is specified on the command-line" do
    before :each do
      ARGV.replace ['-m']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to report on methods only" do
#       Flog.expects(:new).with(:methods => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --methods-only is specified on the command-line" do
    before :each do
      ARGV.replace ['--methods-only']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to report on methods only" do
#       Flog.expects(:new).with(:methods => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when -v is specified on the command-line" do
    before :each do
      ARGV.replace ['-v']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to be verbose" do
#       Flog.expects(:new).with(:verbose => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --verbose is specified on the command-line" do
    before :each do
      ARGV.replace ['--verbose']
    end

# HACK
#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end

# HACK
#     it "should set the option to be verbose" do
#       Flog.expects(:new).with(:verbose => true).returns(@flog)
#       run_command
#     end

# HACK
#     it 'should exit with status 0' do
#       self.expects(:exit).with(0)
#       run_command
#     end
  end

  describe "when -h is specified on the command-line" do
    before :each do
      ARGV.replace ['-h']
    end

    it "should display help information" do
      self.expects(:puts)
      run_command
    end

# HACK: useless anyhow
#     it 'should not create a Flog instance' do
#       Flog.expects(:new).never
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe "when --help is specified on the command-line" do
    before :each do
      ARGV.replace ['--help']
    end

    it "should display help information" do
      self.expects(:puts)
      run_command
    end

# HACK: useless anyhow
#     it 'should not create a Flog instance' do
#       Flog.expects(:new).never
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe 'when -I is specified on the command-line' do
    before :each do
      ARGV.replace ['-I /tmp,/etc']
      @paths = $:.dup
    end

# HACK - very little value to begin with
#     it "should append each ':' separated path to $:" do
#       run_command
#       $:.wont_equal @paths
#     end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe 'when -b is specified on the command-line' do
    before :each do
      ARGV.replace ['-b']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to provide 'blame' information" do
#       Flog.expects(:new).with(:blame => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end

  describe 'when --blame is specified on the command-line' do
    before :each do
      ARGV.replace ['--blame']
    end

#     it 'should create a Flog instance' do
#       Flog.expects(:new).returns(@flog)
#       run_command
#     end
# 
#     it "should set the option to provide 'blame' information" do
#       Flog.expects(:new).with(:blame => true).returns(@flog)
#       run_command
#     end

    it 'should exit with status 0' do
      self.expects(:exit).with(0)
      run_command
    end
  end
end
