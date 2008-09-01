#!/usr/bin/env ruby -ws

# Update the flog scores for a specific set of gems.

$: << 'lib' << '../../ParseTree/dev/lib'
$:.unshift File.expand_path("~/Work/svn/rubygems/lib")

require 'yaml'
require 'flog'
require 'gem_updater'

$u ||= false
$f ||= false

$score_file   = '../dev/scores.yml'
$misc_error   = {:total => -1, :average => -1, :methods => {}}
$syntax_error = {:total => -2, :average => -2, :methods => {}}
$no_gem       = {:total => -4, :average => -4, :methods => {}}

max    = (ARGV.shift || 10).to_i

scores = YAML.load(File.read($score_file)) rescue {}

##
# Save the scores in $score_file.
#--
# Creates a new file, then renames to overwrite the old one.
# Wouldn't it be better to copy the old one, then create a new
# one so you can do a diff?
#++

def save_scores scores
  File.open("#{$score_file}.new", 'w') do |f|
    warn "*** saving scores"
    YAML.dump scores, f
  end
  File.rename "#{$score_file}.new", $score_file
end

GemUpdater::stupid_gems.each do|p|
  scores[p] = $no_gem.dup
end

GemUpdater::initialize_dir

if $u then
  GemUpdater.update_gem_tarballs
  exit 1
end

my_projects = Regexp.union("InlineFortran", "ParseTree", "RubyInline",
                           "RubyToC", "ZenHacks", "ZenTest", "bfts",
                           "box_layout", "flog", "heckle", "hoe",
                           "image_science", "miniunit", "png", "ruby2ruby",
                           "rubyforge", "vlad", "zentest")

$owners = {}

GemUpdater.get_latest_gems.each do |spec|
  name  = spec.name
  owner = spec.authors.compact
  owner = Array(spec.email) if owner.empty?
  owner.map! { |o| o.sub(/\s*[^ \w@.].*$/, '') }
  owner = ["NOT Ryan Davis"] if owner.include? "Ryan Davis" and name !~ my_projects

  # because we screwed these up back before hoe
  owner << "Eric Hodel" if name =~ /bfts|RubyToC|ParseTree|heckle/

  $owners["#{spec.full_name}.tgz"] = owner.uniq || 'omg I have no idea'
end

def score_for dir
  files = `find #{dir} -name \\*.rb | grep -v gen.*templ`.split(/\n/)

  flogger = Flog.new
  flogger.flog_files files
  methods = flogger.totals.reject { |k,v| k =~ /\#none$/ }
  {
    :total => flogger.total,
    :size => methods.size,
    :average => flogger.average,
    :stddev => flogger.stddev,
    :methods => methods
  }
rescue SyntaxError => e
  warn e.inspect + " at " + e.backtrace.first(5).join(', ') if $v
  $syntax_error.dup
rescue => e
  warn e.inspect + " at " + e.backtrace.first(5).join(', ') if $v
  $misc_error.dup
end

# extract all the gems and process the data for them.
begin
  dirty = false
  Dir.chdir "../gems" do
    Dir["*.tgz"].each_with_index do |gem, i|
      project = File.basename gem
      next if scores.has_key? project unless $f and scores[project][:total] < 0
      dirty = true
      begin
        warn gem
        dir = gem.sub(/\.tgz$/, '')

        system "tar -zmxf #{gem} 2> /dev/null"

        Dir.chdir dir do
          system "chmod -R a+r ."
          scores[project] = score_for(File.directory?('lib') ? 'lib' : '.')
        end
      ensure
        system "rm -rf #{dir}"
      end
    end
  end
ensure
  save_scores scores if dirty
end

scores.reject! { |k,v| v[:total].nil? or v[:methods].empty? }

class Hash
  def sorted_methods
    self[:methods].sort_by { |k,v| -v }
  end
end

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

  title "Top #{data.size} #{title}" if title
  data.each_with_index do |(n, c, a, s), i|
    puts "%4d: %-#{max}s: %4d methods, %8.2f +/- %8.2f flog" % [i + 1, n, c, a, s]
  end
end

project_numbers = scores.map { |k,v| [k, v[:methods].map {|_,n| n}.flatten] }
project_stats   = project_numbers.map { |k,v| [k, v.size, v.average, v.stddev] }

title "Statistics" do
  flog_numbers = scores.map { |k,v| v[:total] }
  all_scores = scores.map { |k,v| v[:methods].values }.flatten
  method_counts = scores.map { |k,v| v[:size] }

  puts "total # gems      : %8d" % scores.size
  puts "total # methods   : %8d" % all_scores.size
  puts "avg methods / gem : %8.2f +/- %8.2f" % [method_counts.average, method_counts.stddev]
  puts "avg flog / project: %8.2f +/- %8.2f" % [flog_numbers.average, flog_numbers.stddev]
  puts "avg flog / method : %8.2f +/- %8.2f" % [all_scores.average, all_scores.stddev]
end

def report_worst section, data
  title section do
    max_size = data.map { |k| k.first.size }.max
    data.each_with_index do |(k,v), i|
      puts "%3d: %9.2f: %-#{max_size}s %s" % [i + 1, *yield(k, v)]
    end
  end
end

worst = scores.sort_by { |k,v| -v[:total] }.first(max)
report_worst "Worst Projects EVAR", worst do |project, score|
  owner = $owners[project].join(', ') rescue nil
  raise "#{project} seems not to have an owner" if owner.nil?
  [score[:total], project, owner]
end

worst = {}
scores.each do |long_name, spec|
  name = long_name.sub(/-(\d+\.)*\d+\.gem$/, '')
  spec[:methods].each do |method_name, score|
    worst[[name, method_name]] = score
  end
end

worst = worst.sort_by { |_,v| -v }.first(max)

max_size = worst.map { |(name, meth), score| name.size }.max
title "Worth Methods EVAR"
worst.each_with_index do |((name, meth), score), i|
  puts "%3d: %9.2f: %-#{max_size}s %s" % [i + 1, score, name, meth]
end

report "Methods per Gem", project_stats.sort_by { |n, c, a, sd| -c }.first(max)
report "Avg Flog / Method", project_stats.sort_by { |n, c, a, sd| -a }.first(max)

$score_per_owner = Hash.new(0.0)
$projects_per_owner = Hash.new { |h,k| h[k] = {} }
$owners.each do |project, owners|
  next unless scores.has_key? project # bad project
  owners.each do |owner|
    score = scores[project][:total] || 1000000
    $projects_per_owner[owner][project] = score
    $score_per_owner[owner] += score
  end
end

def report_bad_people section
  title section
  bad_people = yield
  max_size = bad_people.map { |a| a.first.size }.max
  fmt = "%4d: %#{max_size}s: %2d projects %8.1f tot %8.1f avg"
  bad_people.each_with_index do |(name, projects), i|
    avg = projects.values.average
    puts fmt % [i + 1, name, projects.size, $score_per_owner[name], avg]
  end
end

report_bad_people "Top Flog Scores per Developer" do
  $projects_per_owner.sort_by { |k,v| -$score_per_owner[k] }.first(max)
end

report_bad_people "Most Prolific Developers" do |k,v|
  $projects_per_owner.sort_by { |k,v| [-v.size, -$score_per_owner[k]] }.first(max)
end
