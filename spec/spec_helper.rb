# this is my favorite way to require ever
begin
  require 'spec'
rescue LoadError
  require 'rubygems'
  gem 'rspec'
  require 'spec'
end

begin
  require 'mocha'
rescue LoadError
  require 'rubygems'
  gem 'mocha'
  require 'mocha'
end


module Spec::Example::ExampleGroupMethods
  def currently(name, &block)
    it("*** CURRENTLY *** #{name}", &block)
  end
end

Spec::Runner.configure do |config|
  config.mock_with :mocha
end

def fixture_files(paths)
  paths.collect do |path|
    File.expand_path(File.dirname(__FILE__) + '/../spec_fixtures/' + path)
  end
end


$:.unshift File.join(File.dirname(__FILE__), *%w[.. lib])
