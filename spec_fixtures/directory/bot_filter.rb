class BotFilter
  attr_reader :options
  
  def initialize(options = {})
    @options = options
  end
  
  @@kinds = []
  @@filters_registered = false
  
  class << self
    def new(options = {})
      locate_filters(options) unless @@filters_registered
      obj = allocate
      obj.send :initialize, options
      obj
    end
    
    def kinds
      @@kinds
    end
    
    def register(name)
      @@kinds << name
    end
    
    def clear_kinds
      @@kinds = []
      @@filters_registered = false
    end
    
    def get(ident)
      name = ident.to_s.gsub(/(?:^|_)([a-z])/) { $1.upcase }.to_sym
      const_get(name)
    end
    
    def locate_filters(options)
      if options and options[:active_filters]
        options[:active_filters].each do |filter|
          register_filter(filter)
        end
      end
      @@filters_registered = true
    end
    
    def filter_path(name)
      File.expand_path(File.dirname(__FILE__)+"/../lib/filters/#{name}.rb")
    end
    
    def register_filter(name)
      path = filter_path(name)
      raise ArgumentError, "Could not find source code for filter [#{name}] in [#{path}]" unless File.exists? path
      load(path)
      register(name)
    end
  end
  
  def process(data)
    result = data
    self.class.kinds.each do |k|
      if result
        result = BotFilter.get(k).new(options).process(result)
      else
        result = nil
        break
      end
    end
    result
  end
end
