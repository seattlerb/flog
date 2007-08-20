#!/usr/local/bin/ruby -w

code = '../code'

pattern = ARGV.empty? ? nil : Regexp.union(*ARGV)

Dir.mkdir code unless File.directory? code

Dir.chdir code do
  Dir["../gems/*.gem"].each do |gem|
    project = File.basename gem
    next unless project =~ pattern if pattern
    dir = project.sub(/\.gem$/, '')
    warn dir
    unless File.directory? dir then
      Dir.mkdir dir
      Dir.chdir dir do
        system "(tar -Oxf ../#{gem} data.tar.gz | tar zxf -) 2> /dev/null"
      end
    end
  end
end
