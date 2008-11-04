module Centerstone #:nodoc:
  module Acts #:nodoc:
    module Range
      
      def self.included(base) # :nodoc:
        base.extend ClassMethods
        unless ActiveRecord::Base.respond_to?(:end_dated_association_date)
          class << ActiveRecord::Base
          	attr :end_dated_association_date, true
        	end
        	ActiveRecord::Base.end_dated_association_date = Proc.new { Time.now }
        end
      end

      module InstanceMethods
        def self.included(base) # :nodoc:
          base.extend ClassMethods
        end
        
        %w{begin end}.each do |bound|
          define_method "acts_as_range_#{bound}" do
            send(self.class.send("acts_as_range_#{bound}_attr").to_sym)
          end
          
          define_method "acts_as_range_#{bound}=" do |val|
            send((self.class.send("acts_as_range_#{bound}_attr").to_s + '=').to_sym,  val)
          end
        end
        
        # convert this object into a range
        # do something about nil/unspecified ends?
        def to_range
          begin_point = acts_as_range_begin
          end_point   = acts_as_range_end
          
          begin_point ... end_point
        end
           
        # does the range for this object include the specified point?
        def include?(point)
          true if self.class.find(self.id, :on => point)
        rescue
          false
        end
        
        def contained_by?(range)
          if range.respond_to?(:acts_as_range_begin)
            # if this is really a range-ish object
            if range.acts_as_range_begin and range.acts_as_range_end
              # if it can actually be represented as a range
              return contained_by?(range.to_range)
            elsif range.acts_as_range_begin or range.acts_as_range_end
              # if at least one bound is defined, compare that bound
              if range.acts_as_range_begin
                return false unless acts_as_range_begin
                return acts_as_range_begin >= range.acts_as_range_begin
              end
              
              if range.acts_as_range_end
                return false unless acts_as_range_end
                return acts_as_range_end <= range.acts_as_range_end
              end
            else
              # the given "range" has no bounds, thus it contains all
              return true
            end
          end
          
          # if the given range includes both bounds, it contains this object
          # Note: Checking the end bound is a little tricky because of the exclusion choice with ranges (but not with acts_as_range)
          range.include?(acts_as_range_begin) and (range.include?(acts_as_range_end) or ((range.last == acts_as_range_end) and (range.exclude_end? == to_range.exclude_end?)))
        end
        
        def containing?(target)
          if target.respond_to?(:acts_as_range_begin)
            # if this is really a range-ish object
            # enough work has been done on contained_by?, so let's use that if we can
            target.contained_by?(self)
          else
            if target.is_a?(::Range)  # core Range class, not this Range module
              if acts_as_range_begin and acts_as_range_end
                # if this object can actually be represented as a range
                # if this object's range includes both bounds of the given range, it contains that range
                # Note: Checking the end bound is a little tricky because of the exclusion choice with ranges (but not with acts_as_range)
                to_range.include?(target.first) and (to_range.include?(target.last) or ((to_range.last == target.last) and (to_range.exclude_end? == target.exclude_end?)))
              elsif acts_as_range_begin or acts_as_range_end
                # if at least one bound is defined, compare that bound
                if acts_as_range_begin
                  return acts_as_range_begin <= target.first
                end
                
                if acts_as_range_end
                  # note the problem with checking the end bound above
                  return (acts_as_range_end > target.last or ((acts_as_range_end == target.last) and target.exclude_end?))
                end
              else
                # this object's "range" has no bounds, thus it contains all
                true
              end
            else
              # this is a single point, so check it
              begin_point = acts_as_range_begin || target
              end_point   = acts_as_range_end   || target
            
              (begin_point ... end_point).include?(target) or ((begin_point <= target) and !acts_as_range_end)
            end
          end
        end
        alias_method :contains?, :containing?
        
        def overlapping?(target)
          # contained by target or containing target
          return true if contained_by?(target) or containing?(target)
          
          # or containing either bound
          if target.respond_to?(:acts_as_range_begin)
            containing_begin = containing?(target.acts_as_range_begin) if target.acts_as_range_begin
            containing_end   = containing?(target.acts_as_range_end)   if target.acts_as_range_end
            
            return (containing_begin or containing_end)
          else
            if target.is_a?(::Range)  # core Range class, not this Range module
              return (containing?(target.first) or containing?(target.last))
            end
          end
          
          # if it got this far
          false
        end
        alias_method :overlaps?, :overlapping?
        
        def before?(point)
          return false unless point
          return false unless acts_as_range_end
          
          if point.respond_to?(:acts_as_range_begin)
            return before?(point.acts_as_range_begin)
          end
          
          acts_as_range_end < point
        end
        
        def after?(point)
          return false unless point
          return false unless acts_as_range_begin

          if point.respond_to?(:acts_as_range_end)
            return after?(point.acts_as_range_end)
          end
          
          acts_as_range_begin > point
        end
       
        module ClassMethods
          
          %w{begin end}.each do |bound|
            define_method "acts_as_range_#{bound}_attr" do
              acts_as_range_configuration[bound.to_sym]
            end
          end
          
          # add new options to Foo.find:
          #    :contain      => t1 .. t2 - return objects whose spans contain this time interval
          #    :containing   => t1 .. t2 - return objects whose spans contain this time interval
          #    :contained_by => t1 .. t2 - return objects whose spans are contained by this time interval
          #    :overlapping  => t1 .. t2 - return objects whose spans overlap this time interval
          #    :on           => t1       - return objects whose spans contain this time point
          #    :before       => t1       - return objects whose spans are completed on or before this time point
          #    :after        => t1       - return objects whose spans begin on or after this time point 
          #
          # Note that each of the time interval methods will also take an object of this
          # class and will use the time interval from that object as search parameters.
          def find_with_range_restrictions(*args)
            original_args = args.dup
            options = extract_options_from_args!(args)
            
            # which new arguments do we recognize, and which scoping methods do they use?
            # eh, I don't like 'on' or 'contain'.  Like the non-database instance methods
            # above, 'containing' could handle both cases of range and point
            method_map = {  :contain      => :with_containing_scope, 
                            :containing   => :with_containing_scope, 
                            :contained_by => :with_contained_scope,
                            :overlapping  => :with_overlapping_scope, 
                            :on           => nil,
                            :before       => nil, 
                            :after        => nil }
                           
            # find objects with time intervals containing this time point            
            if options.has_key? :on
              return with_containing_scope(options[:on], options[:on]) do
                find_without_range_restrictions(*remove_args(original_args, method_map.keys))
              end
            end
           
            # find objects with time intervals containing this time point            
            if options.has_key? :before
              return with_before_scope(options[:before]) do
                find_without_range_restrictions(*remove_args(original_args, method_map.keys))
              end
            end
           
            # find objects with time intervals containing this time point            
            if options.has_key? :after
              return with_after_scope(options[:after]) do
                find_without_range_restrictions(*remove_args(original_args, method_map.keys))
              end
            end
               
            # otherwise, find objects with time intervals matching this range
            method_map.keys.each do |kind|              
              if options.has_key? kind
                x = ranged_lookup(options[kind]) do |start, stop|
                  self.send(method_map[kind], start, stop) do
                    find_without_range_restrictions(*remove_args(original_args, method_map.keys))
                  end                           
                end
                # Patch for find :first, :conditions => 'impossible'
                # Could be cleaner, but this handles it
                return x == [nil] ? nil : x
              end                           
            end
                 
            # otherwise, find objects with time intervals active now
            if acts_as_range_configuration[:end_dated]
              with_current_time_scope { find_without_range_restrictions(*original_args) }
            else
              find_without_range_restrictions(*original_args)
            end
          end

          def count_with_range_restrictions(*args)
            if acts_as_range_configuration[:end_dated]
              with_current_time_scope { count_without_range_restrictions(*args) }
            else
              count_without_range_restrictions(*args)
            end
          end

          def calculate_with_range_restrictions(*args)
            if acts_as_range_configuration[:end_dated]
              with_current_time_scope { calculate_without_range_restrictions(*args) }
            else
              calculate_without_range_restrictions(*args)
            end
          end

          # break out an args list, add in new options, return a new args list
          def add_args(args, added)
            args << extract_options_from_args!(args).merge(added)
          end

        protected
       
          # break out an args list, remove specified options, return a new args list
          def remove_args(args, removed)                                     
            options = extract_options_from_args!(args)
            removed.each {|k| options.delete(k)}
            args << options
            args.last.keys.length > 0 ? args : args.first
          end                                              

          # provide for lookups on a date range /or/ an acts_as_range object (filtering object out)
          def ranged_lookup(obj)        
            filter_object = obj.respond_to?(:acts_as_range_begin)
            start, stop = filter_object ? [obj.acts_as_range_begin, obj.acts_as_range_end] : [obj.first, obj.last]
            result = yield(start, stop)
            filter_object ? (Set.new(result) - Set.new([obj])).to_a : result
          end  

          # find objects with intervals including the current time  
          def with_current_time_scope(&block)
            t =  ActiveRecord::Base.end_dated_association_date.call
            if t.respond_to? :first
              with_overlapping_scope(t.first, t.last, &block)
            else
              with_containing_scope(t, t, &block)
            end
          end
                                
          # find objects which are entirely before the specified time
          def with_before_scope(t, &block)
            with_scope({:find => { :conditions => ["(#{table_name}.#{acts_as_range_end_attr} is not null and #{table_name}.#{acts_as_range_end_attr} < ?)", t ] } }, :merge, &block)
          end    
                                                                    
          # find objects which are entirely after the specified time
          def with_after_scope(t, &block)
            with_scope({:find => { :conditions => ["(#{table_name}.#{acts_as_range_begin_attr} is not null and #{table_name}.#{acts_as_range_begin_attr} > ?)", t ] } }, :merge, &block)
          end

          # find objects with intervals contained by the interval t1 .. t2
          def with_contained_scope(t1, t2, &block)  
            conditions = []
            args = []

            if t1.nil? 
              if t2.nil?
                conditions << "(1=1)"
              else
                conditions << "(#{table_name}.#{acts_as_range_end_attr} is not NULL and #{table_name}.#{acts_as_range_end_attr} < ?)"
                args << t2
              end
            elsif t2.nil?                                                
              conditions << "(#{table_name}.#{acts_as_range_begin_attr} is not NULL and #{table_name}.#{acts_as_range_begin_attr} >= ?)"
              args << t1
            else
              conditions << "(#{table_name}.#{acts_as_range_begin_attr} is not NULL and #{table_name}.#{acts_as_range_begin_attr} >= ?)"
              args << t1
              conditions << "(#{table_name}.#{acts_as_range_end_attr} is not NULL and #{table_name}.#{acts_as_range_end_attr} < ?)"
              args << t2              
            end

            conditions = ([ conditions.join(' AND ') ] << args).flatten
            with_scope({:find => { :conditions => conditions } }, :merge, &block)
          end             

          # find objects with intervals containing the interval t1 .. t2
          def with_containing_scope(t1, t2, &block)    
            conditions = []
            args = []

            if t1.nil?
              conditions << "(#{table_name}.#{acts_as_range_begin_attr} is NULL)"
            else                                                
              conditions << "(#{table_name}.#{acts_as_range_begin_attr} <= ? or #{table_name}.#{acts_as_range_begin_attr} IS NULL)"
              args << t1
            end
            
            if t2.nil?        
              conditions << "(#{table_name}.#{acts_as_range_end_attr} is NULL)"
            else
              conditions << "(#{table_name}.#{acts_as_range_end_attr} > ? or #{table_name}.#{acts_as_range_end_attr} IS NULL)"
              args << t2
            end

            conditions = ([ conditions.join(' AND ') ] << args).flatten
            with_scope({:find => { :conditions => conditions } }, :merge, &block)
          end             

          # find objects with intervals overlapping the interval t1 .. t2
          def with_overlapping_scope(t1, t2, &block)
            [with_containing_scope(t1, t1, &block)].flatten | [with_containing_scope(t2, t2, &block)].flatten | [with_contained_scope(t1, t2, &block)].flatten
          end
        end
      end
    
      module ClassMethods
        def acts_as_range(options = {})
          return if acts_as_range?  # don't let this be done twice
          class_inheritable_reader :acts_as_range_configuration          
          raise "options must be a Hash" unless options.is_a?(Hash)
          
          acts_as_range_configure_class({ :begin => :begin, :end => :end }.update(options))
        end
        
        def acts_as_range?
          included_modules.include?(InstanceMethods)
        end
        
        # ensure that the beginning of the interval does not follow its end
        def validates_interval
          configuration = { :message => "#{acts_as_range_configuration[:begin].to_s.humanize} must be before #{acts_as_range_configuration[:end].to_s.humanize}.", :on => [ :save, :update ] }
          configuration[:on].each do |symbol|
            send(validation_method(symbol)) do |record|
              unless configuration[:if] && !evaluate_condition(configuration[:if], record)
                start, stop = record.acts_as_range_begin, record.acts_as_range_end
                unless start.nil? or stop.nil? or start <= stop
                  record.errors.add(acts_as_range_configuration[:begin], configuration[:message])
                end
              end
            end                         
          end
        end

      protected
        
        def acts_as_range_configure_class(options = {})
          include InstanceMethods
          write_inheritable_attribute(:acts_as_range_configuration, options)
          
          class << self
            %w{find count calculate}.each do |method|
              alias_method_chain method.to_sym, :range_restrictions
            end
          end
          
          validates_interval
        end        
      end
    end
  end
end
