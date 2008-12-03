#!/usr/bin/ruby -ws

$: << 'lib' << '../../ParseTree/dev/lib' << '../../flog/dev/lib'

$v ||= false # HACK

require 'rubygems'
require 'flog'

require 'gauntlet'
require 'pp'

class FlogGauntlet < Gauntlet
  $owners       = {}
  $score_file   = 'flog-scores.yml'
  $misc_error   = {:total => -1, :average => -1, :methods => {}}
  $syntax_error = {:total => -2, :average => -2, :methods => {}}
  $no_gem       = {:total => -4, :average => -4, :methods => {}}

  # copied straight from hoedown.rb 
  my_projects = %w[InlineFortran ParseTree RubyInline RubyToC
                   ZenHacks ZenTest bfts box_layout
                   change_class flay flog gauntlet heckle
                   hoe image_science miniunit minitest
                   minitest_tu_shim png ruby2ruby ruby_parser
                   rubyforge test-unit un vlad zenprofile
                   zentest]

  MY_PROJECTS = Regexp.union(*my_projects)

  def run name
    warn name
    self.data[name] = score_for '.'
    self.dirty = true
  end

  def display_report max = 10
    scores = @data.reject { |k,v| v[:total].nil? or v[:methods].empty? }
    project_numbers = scores.map { |k,v| [k, v[:methods].values] }
    project_stats = project_numbers.map { |k,v| [k, scores[k][:size], v.average, v.stddev] }

    method_count = 0
    project_stats.each do |_, n, _, _|
      method_count += n
    end

    group_by_owner

    title "Statistics" do
      flog_numbers = scores.map { |k,v| v[:total] }
      method_counts = scores.map { |k,v| v[:size] }

      puts "total # gems      : %8d" % scores.size
      puts "total # methods   : %8d" % method_count
      puts "avg methods / gem : %8.2f (%8.2f stddev)" % [method_counts.average, method_counts.stddev]
      puts "avg flog / gem    : %8.2f (%8.2f stddev)" % [flog_numbers.average, flog_numbers.stddev]
    end
    
    worst = scores.sort_by { |k,v| -v[:total] }.first(max)
    report_worst "Worst Projects EVAR", worst do |project, score|
      owner = $owners[project].join(', ') rescue nil
      owner = "Some Lazy Bastard" if owner.empty?
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
        next if owner =~ /FI\XME full name|NOT Ryan Davis/
        score = scores[project][:total] || 1000000
        $projects_per_owner[owner][project] = score
        $score_per_owner[owner] += score
      end
    end

    report_bad_people "Top Flog Scores per Developer" do
      $projects_per_owner.sort_by { |k,v| -v.values.average }.first(max)
    end

    report_bad_people "Most Prolific Developers" do |k,v|
      $projects_per_owner.sort_by { |k,v| [-v.size, -$score_per_owner[k]] }.first(max)
    end
  end

  ############################################################
  # OTHER
  ############################################################

  def score_for dir
    # files = `find #{dir} -name \\*.rb | grep -v gen.*templ`.split(/\n/)
    files = Dir["**/*.rb"].reject { |f| f =~ /gen.*templ|gemspec.rb/ }

    flogger = Flog.new
    flogger.flog_files files
    methods = flogger.totals.reject { |k,v| k =~ /\#none$/ }
    n = 20
    topN = Hash[*methods.sort_by { |k,v| -v }.first(n).flatten]
    {
      :max     => methods.values.max,
      :total   => flogger.total,
      :size    => methods.size,
      :average => flogger.average,
      :stddev  => flogger.stddev,
      :methods => topN,
    }
  rescue SyntaxError => e
    warn e.inspect + " at " + e.backtrace.first(5).join(', ') if $v
    $syntax_error.dup
  rescue => e
    warn e.inspect + " at " + e.backtrace.first(5).join(', ') if $v
    $misc_error.dup
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
      puts "%4d: %-#{max}s: %5d methods, %8.2f +/- %8.2f flog" % [i + 1, n, c, a, s]
    end
  end

  def report_bad_people section
    title section
    bad_people = yield
    max_size = bad_people.map { |a| a.first.size }.max
    fmt = "%4d: %-#{max_size}s: %2d projects %8.1f tot %8.1f avg"
    bad_people.each_with_index do |(name, projects), i|
      avg = projects.values.average
      puts fmt % [i + 1, name, projects.size, $score_per_owner[name], avg]
    end
  end

  def report_worst section, data
    title section do
      max_size = data.map { |k| k.first.size }.max
      data.each_with_index do |(k,v), i|
        puts "%3d: %9.2f: %-#{max_size}s %s" % [i + 1, *yield(k, v)]
      end
    end
  end

  def group_by_owner
    latest_gems.each do |spec|
      name  = spec.name
      owner = spec.authors.compact
      owner = Array(spec.email) if owner.empty?
      owner.map! { |o| o.sub(/\s*[^ \w@.].*$/, '') }
      owner = ["NOT Ryan Davis"] if owner.include? "Ryan Davis" and name !~ MY_PROJECTS

      # because we screwed these up back before hoe
      owner << "Eric Hodel" if name =~ /bfts|RubyToC|ParseTree|heckle/

      $owners[spec.full_name] = owner.uniq || 'omg I have no idea'
    end
  end
end

max     = (ARGV.shift || 10).to_i
filter  = ARGV.shift
filter  = Regexp.new filter if filter
flogger = FlogGauntlet.new
flogger.run_the_gauntlet filter
flogger.display_report max
