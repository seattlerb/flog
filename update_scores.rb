#!/usr/local/bin/ruby -ws

$: << 'lib'
$: << '../../ParseTree/dev/lib'
require 'flog'
require 'rubygems/source_info_cache'

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

my_projects = Regexp.union("InlineFortran", "ParseTree", "RubyInline", "ZenTest", "bfts", "box_layout", "flog", "heckle", "image_science", "miniunit", "png", "ruby2ruby", "vlad", "zentest", "ZenHacks", "rubyforge", "RubyToC", "hoe")

$owners = {}
cache = Marshal.load(File.read(Gem::SourceInfoCache.new.cache_file))
cache['http://gems.rubyforge.org'].source_index.latest_specs.map { |name, spec|
  owner = spec.authors.compact
  owner = Array(spec.email) if owner.empty?
  owner.map! { |o| o.sub(/\s*[^ \w@.].*$/, '') }
  owner = ["NOT Ryan Davis"] if owner.include? "Ryan Davis" and name !~ my_projects

  # because we screwed these up back before hoe
  owner << "Eric Hodel" if name =~ /bfts|RubyToC|ParseTree|heckle/

  $owners["#{spec.full_name}.gem"] = owner.uniq
}

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

scores.reject! { |k,v| v.first.nil? or Fixnum === v.last or v.last.last < 0 }

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

project_numbers = scores.map { |k,v| [k, v[1..-1].map {|_,n| n}.flatten] }
project_stats   = project_numbers.map { |k,v| [k, v.size, v.average, v.stddev] }

title "Statistics" do
  flog_numbers = scores.map { |k,v| v.first }
  all_scores = scores.map { |k,v| v[1..-1].map { |_,n| n } }.flatten
  method_counts = project_stats.map { |n,c,a,s| c }

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

worst = scores.sort_by { |k,v| -v.first }.first(max)
report_worst "Worst Projects EVAR", worst do |project, score|
  [score.first, project, $owners[project].join(', ')]
end

worst = scores.sort_by { |k,v| -v.last.last }.first(max)
report_worst "Worst Methods EVAR", worst do |project, methods|
  [methods.last.last, project, methods.last.first]
end

report "Methods per Gem", project_stats.sort_by { |n, c, a, sd| -c }.first(max)
report "Avg Flog / Method", project_stats.sort_by { |n, c, a, sd| -a }.first(max)

$score_per_owner = Hash.new(0.0)
$projects_per_owner = Hash.new { |h,k| h[k] = {} }
$owners.each do |project, owners|
  next unless scores.has_key? project # bad project
  owners.each do |owner|
    score = scores[project].first || 10000
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
  $projects_per_owner.sort_by { |k,v| -v.size }.first(max)
end
