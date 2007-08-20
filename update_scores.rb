#!/usr/local/bin/ruby -ws

$: << 'lib'
$: << '../../ParseTree/dev/lib'
require 'flog'

$u ||= false
$f ||= false

$score_file = '../dev/scores.yml'
$misc_error = [-1]
$syntax_error = [-2]
$no_methods = ["", -3]
$no_gem = [-4]

max = (ARGV.shift || 10).to_i

scores = YAML.load(File.read($score_file)) rescue {}

["ruby-aes-table1-1.0.gem",
 "ruby-aes-unroll1-1.0.gem",
 "hpricot-scrub-0.2.0.gem",
 "extract_curves-0.0.1.gem",
 "rfeedparser-ictv-0.9.931.gem",
 "spec_unit-0.0.1.gem"].each do|p|
  scores[p] = $no_gem.dup
end

Dir.mkdir "../gems" unless File.directory? "../gems"

if $u then
  puts "updating mirror"
  require 'rubygems/source_info_cache'

  Dir.chdir "../gems" do
    cache = Gem::SourceInfoCache.cache_data['http://gems.rubyforge.org']

    gems = Dir["*.gem"]
    old = gems - cache.source_index.latest_specs.values.map { |spec|
      "#{spec.full_name}.gem"
    }

    puts "deleting #{old.size} gems"
    old.each do |gem|
      scores.delete gem
      File.unlink gem
    end

    new = cache.source_index.latest_specs.map { |name, spec|
      "#{spec.full_name}.gem"
    } - gems

    puts "fetching #{new.size} gems"
    new.each do |gem|
      next if scores[gem] == $no_gem unless $f # FIX
      unless system "wget http://gems.rubyforge.org/gems/#{gem}" then
        scores[gem] = $no_gem
      end
    end
  end
end

def score_for dir
  files = `find #{dir} -name \\*.rb | grep -v gen.*templ`.split(/\n/)

  flogger = Flog.new
  flogger.flog_files files
  methods = flogger.totals.reject { |k,v| k =~ /\#none$/ }.sort_by { |k,v| v }
  methods = [$no_methods.dup] if methods.empty?
  [flogger.total] + methods
rescue SyntaxError => e
  warn e.inspect + " at " + e.backtrace.first(5).join(', ') if $v
  $syntax_error.dup
rescue => e
  warn e.inspect + " at " + e.backtrace.first(5).join(', ') if $v
  $misc_error.dup
end

def save_scores scores
  File.open("#{$score_file}.new", 'w') do |f|
    warn "*** saving scores"
    YAML.dump scores, f
  end
  File.rename "#{$score_file}.new", $score_file
end

begin
  dirty = false
  Dir.chdir "../gems" do
    Dir["*.gem"].each_with_index do |gem, i|
      project = File.basename gem
      next if scores.has_key? project unless $f and scores[project][0] < 0
      dirty = true
      begin
        warn gem
        dir = gem.sub(/\.gem$/, '')
        Dir.mkdir dir
        Dir.chdir dir do
          system "(tar -Oxf ../#{gem} data.tar.gz | tar zxf -) 2> /dev/null"
          system "chmod -R a+r ."
          scores[project] = score_for(File.directory?('lib') ? 'lib' : '.')
        end
      ensure
        system "rm -rf #{dir}"
      end

      if i % 500 == 0 then
        save_scores scores
      end
    end
  end
ensure
  save_scores scores if dirty
end

scores.reject! { |k,v| Fixnum === v.last or v.last.last < 0 }

class Array
  def sum
    sum = 0
    self.each { |i| sum += i }
    sum
  end

  def average
    return self.sum / self.length.to_f
  end

  def sample_variance
    avg = self.average
    sum = 0
    self.each { |i| sum += (i - avg) ** 2 }
    return (1 / self.length.to_f * sum)
  end

  def stddev
    return Math.sqrt(self.sample_variance)
  end
end

def title heading
  puts
  puts "#{heading}:"
  puts
  yield if block_given?
end

def report title, data
  max = data.map { |d| d.first.size }.max

  title "Top #{data.size} #{title}"
  data.each_with_index do |(n, c, a, s), i|
    puts "%4d: %-#{max}s: %4d methods, %8.2f +/- %8.2f flog" % [i + 1, n, c, a, s]
  end
end

project_numbers = scores.map { |k,v| [k, v[1..-1].map {|_,n| n}.flatten] }
project_stats   = project_numbers.map { |k,v| [k, v.size, v.average, v.stddev] }

title "Statistics" do
  flog_numbers = scores.map { |k,v| v.first }
  all_scores = scores.map { |k,v| v[1..-1].map { |_,n| n } }.flatten
  method_counts   = project_stats.map { |n,c,a,s| c }

  puts "total # gems      : %8d" % scores.size
  puts "total # methods   : %8d" % all_scores.size
  puts "avg methods / gem : %8.2f +/- %8.2f" % [method_counts.average, method_counts.stddev]
  puts "avg flog / project: %8.2f +/- %8.2f" % [flog_numbers.average, flog_numbers.stddev]
  puts "avg flog / method : %8.2f +/- %8.2f" % [all_scores.average, all_scores.stddev]
end

title "Worst projects evar" do
  projects = scores.sort_by { |k,v| -v.first }.first(max)

  projects.each_with_index do |(project, score), i|
    puts "%3d: %9.2f: %s" % [i+1, score.first, project]
  end
end

title "Worst methods evar" do
  top = scores.sort_by { |k,v| -Array(v.last).last }.first(max)
  max_size = top.map { |k| k.first.size }.max

  methods = scores.sort_by { |k,v| -Array(v.last).last }.first(max)
  methods.each_with_index do |(project, methods), i|
    puts "%3d: %9.2f: %-#{max_size}s %s" % [i+1, methods.last.last, project, methods.last.first]
  end
end

methods = project_stats.sort_by { |name, count, avg, stddev| -count }.first(max)
report "methods per project", methods

flogs = project_stats.sort_by { |name, count, avg, stddev| -avg }.first(max)
report "avg flog / method", flogs
