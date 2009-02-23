require 'minitest/autorun'
require 'minitest/spec'
require 'ostruct'

# must_be
# must_be_close_to
# must_be_empty
# must_be_instance_of
# must_be_kind_of
# must_be_nil
# must_be_same_as
# must_be_within_delta
# must_be_within_epsilon
# must_equal
# must_include
# must_match
# must_raise
# must_respond_to
# must_send
# must_throw

class MiniTest::Spec
  def self.currently(name, &block)
    it("*** CURRENTLY *** #{name}", &block)
  end
end

class Object # HACK - mocha blows
  def ignore(*args)
    self
  end

#  alias :returns :ignore
  alias :expects :ignore
  alias :with    :ignore
#  alias :never   :ignore
#  alias :raises  :ignore
#  alias :times   :ignore

  alias :stubs   :ignore

  def stub(name, methods = {})
    o = OpenStruct.new
    methods.each do |k,v|
      o.send "#{k}=", v
    end

    o.puts = nil # HACK
    o
  end
end

class Proc # HACK - worthless
  def wont_raise_error *args
    call
  end
end

def fixture_files(paths)
  paths.collect do |path|
    File.expand_path(File.dirname(__FILE__) + '/../spec_fixtures/' + path)
  end
end

$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])
