require 'rubygems/remote_fetcher'

$u ||= false

module GemUpdater
  GEMURL = URI.parse 'http://gems.rubyforge.org'

  @@index = nil

  def self.stupid_gems
    ["ruby-aes-table1-1.0.gem", # stupid dups usually because of "dash" renames
     "ruby-aes-unroll1-1.0.gem",
     "hpricot-scrub-0.2.0.gem",
     "extract_curves-0.0.1.gem",
     "extract_curves-0.0.1-i586-linux.gem",
     "extract_curves-0.0.1-mswin32.gem",
     "rfeedparser-ictv-0.9.931.gem",
     "spec_unit-0.0.1.gem"]
  end

  def self.initialize_dir
    Dir.mkdir "../gems" unless File.directory? "../gems"
    self.in_gem_dir do
      File.symlink ".", "cache" unless File.exist? "cache"
    end
  end

  def self.get_source_index
    return @@index if @@index

    dump = if $u or not File.exist? '.source_index' then
             url = GEMURL + "Marshal.#{Gem.marshal_version}.Z"
             dump = Gem::RemoteFetcher.fetcher.fetch_path url
             dump = Gem.inflate dump
             open '.source_index', 'wb' do |io| io.write dump end
           else
             open '.source_index', 'rb' do |io| io.read end
           end

    @@index = Marshal.load dump
  end

  def self.get_latest_gems
    @@cache ||= get_source_index.latest_specs
  end

  def self.get_gems_by_name
    @@by_name ||= Hash[*get_latest_gems.map { |gem|
                         [gem.name, gem, gem.full_name, gem]
                       }.flatten]
  end

  def self.dependencies_of name
    index = self.get_source_index
    get_gems_by_name[name].dependencies.map { |dep| index.search(dep).last }
  end

  def self.dependent_upon name
    get_latest_gems.find_all { |gem|
      gem.dependencies.any? { |dep| dep.name == name }
    }
  end

  def self.update_gem_tarballs
    GemUpdater.initialize_dir

    latest = GemUpdater.get_latest_gems

    puts "updating mirror"

    self.in_gem_dir do
      gems = Dir["*.gem"]
      tgzs = Dir["*.tgz"]

      old = tgzs - latest.map { |spec| "#{spec.full_name}.tgz" }
      unless old.empty? then
        puts "deleting #{old.size} tgzs"
        old.each do |tgz|
          File.unlink tgz
        end
      end

      new = latest.map { |spec|
        "#{spec.full_name}.tgz"
      } - tgzs

      puts "fetching #{new.size} tgzs"

      latest.sort.each do |spec|
        full_name = spec.full_name
        tgz_name = "#{full_name}.tgz"
        gem_name = "#{full_name}.gem"

        next if tgzs.include? tgz_name

        unless gems.include? gem_name then
          begin
            warn "downloading #{full_name}"
            Gem::RemoteFetcher.fetcher.download(spec, GEMURL, Dir.pwd)
          rescue Gem::RemoteFetcher::FetchError
            warn "  failed"
            next
          end
        end

        warn "converting #{gem_name} to tarball"

        unless File.directory? full_name then
          system "gem unpack cache/#{gem_name}"
          system "gem spec -l cache/#{gem_name} > #{full_name}/gemspec.rb"
        end

        system "tar zmcf #{tgz_name} #{full_name}"
        system "rm -rf   #{full_name} #{gem_name}"
      end
    end
  end

  def self.each_gem filter = /^[\w-]+-\d+(\.\d+)*\.tgz$/
    self.in_gem_dir do
      Dir["*.tgz"].each do |tgz|
        next unless tgz =~ filter

        yield File.basename(tgz, ".tgz")
      end
    end
  end

  def self.with_gem name
    self.in_gem_dir do
      begin
        system "tar zxmf #{name}.tgz 2> /dev/null"
        Dir.chdir name do
          yield name
        end
      ensure
        system "rm -r #{name}"
      end
    end
  end

  def self.load_yaml path, default = {}
    YAML.load(File.read(path)) rescue default
  end

  def self.save_yaml path, data
    File.open("#{path}.new", 'w') do |f|
      warn "*** saving #{path}"
      YAML.dump data, f
    end
    File.rename "#{path}.new", path
  end

  def self.in_gem_dir
    Dir.chdir "../gems" do
      yield
    end
  end
end
