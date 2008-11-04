module Centerstone #:nodoc:
  module Acts #:nodoc:
    module DateRange
      include ActionView::Helpers::DateHelper
      
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
           
        # does the range for this object include the specified point in time?                              
        def include?(t)
          true if self.class.find(self.id, :on => t)
        rescue
          false
        end
        
        # expire this object
        def expire(time = Time.now)
          return false if acts_as_range_end
          if time.is_a?(Time)
            self.acts_as_range_end = 1.second.ago(time)
          elsif time.is_a?(Date)
            self.acts_as_range_end = time - 1 
          end
          save!
        end
        
        # see if this object is expired
        def expired?(time = Time.now)
          return false if not acts_as_range_end
          return acts_as_range_end <= time
        end     
        
        # return a description of how long this object (has) lived (as of some specified point in time)
        def lifetime(time = Time.now)
          return 'forever' if acts_as_range_begin.nil?
          return 'in future' if acts_as_range_end.nil? and acts_as_range_begin > time
          distance_of_time_in_words(acts_as_range_begin, acts_as_range_end || time)
        end     
     
        def limit_date_range(&block)
          time = [ acts_as_range_begin, acts_as_range_end ]
          prior, ActiveRecord::Base.end_dated_association_date = ActiveRecord::Base.end_dated_association_date, Proc.new { time }
          yield
        ensure
          ActiveRecord::Base.end_dated_association_date = prior
        end
     
        def destroy_without_callbacks
          unless new_record?
            if acts_as_range_configuration[:end_dated]
              now = self.default_timezone == :utc ? Time.now.utc : Time.now
              self.class.update_all self.class.send(:sanitize_sql, ["#{acts_as_range_end_attr} = ?", now]), "id = #{quote_value(id)}"
            else 
              super
            end
          end
          freeze
        end
        
       
        module ClassMethods

          # find objects with intervals including the current time  
          def with_current_time_scope(&block)
            t = ActiveRecord::Base.end_dated_association_date.call
            if t.respond_to? :first
              with_overlapping_scope(t.first, t.last, &block)
            else
              with_containing_scope(t, t, &block)
            end
          end
          
        end
      end
    
      module ClassMethods
        def acts_as_date_range(options = {})
          return if acts_as_date_range?  # don't let this be done twice
          raise "options must be a Hash" unless options.is_a?(Hash)
          
          acts_as_range({ :begin => :begin_time, :end => :end_time }.update(options))
          acts_as_date_range_configure_class(options)
        end
        
        def acts_as_date_range?
          included_modules.include?(InstanceMethods)
        end
        
        def sequentialized?
          sequentialized_on ? true : false
        end
        
        def sequentialized_on
          acts_as_range_configuration[:sequentialize]
        end
        
      protected
        
        def acts_as_date_range_singleton_sequentialize_class
          before_validation_on_create do |obj|
            obj.acts_as_range_begin ||= Time.now
            true
          end
      
          before_create do |obj|
            # Expiring any open object 
            obj.class.find(:all, :conditions => "#{acts_as_range_end_attr} is null").each {|o| o.expire(obj.acts_as_range_begin)}
            true   
          end
          
          validate_on_create do |obj|
            # If any record defines a date after the begin_date then data is corrupt
            if obj.class.count(:conditions => ["#{acts_as_range_begin_attr} >= ? or #{acts_as_range_end_attr} > ?",
                                               obj.acts_as_range_begin, obj.acts_as_range_begin]) > 0
              obj.errors.add(acts_as_range_begin_attr, 'Begin time is before other keys begin time or end time')
            end
            true
          end
        end
        
        module ParamExtension
          def to_sql
            collect { |elem|  "#{elem} = ?" }.join(' and ')
          end
          
          def to_attributes_for(obj)
            collect { |elem|  obj.attributes[elem.to_s] }
          end
        end
        
        
        def acts_as_date_range_param_sequentialize_class(*params)
          params.extend(ParamExtension)
          
          before_validation_on_create do |obj|
            obj.acts_as_range_begin ||= Time.now
            true
          end
                  
          before_create do |obj|
            # Expiring any open object
            obj.class.find(:all, :conditions => ["#{acts_as_range_end_attr} is null and #{params.to_sql}", 
                                                 params.to_attributes_for(obj)].flatten).each do |o|
              o.expire(obj.acts_as_range_begin)
            end
            true   
          end
          
          validate_on_create do |obj|
            # If any record defines a date after the begin_date then data is corrupt
            if obj.class.count(:conditions => ["#{params.to_sql} and (#{acts_as_range_begin_attr} >= ? or #{acts_as_range_end_attr} > ?)",
                                                 params.to_attributes_for(obj), obj.acts_as_range_begin, obj.acts_as_range_begin].flatten) > 0
              obj.errors.add(acts_as_range_begin_attr, 'Begin time is before other begin time or end time')
            end
            true
          end
        end
        
        def acts_as_date_range_sequentialize_class(*params)
          params.flatten!
          if params == [true]
            acts_as_date_range_singleton_sequentialize_class
          else
            acts_as_date_range_param_sequentialize_class(*params)
          end
        end
      
        def acts_as_date_range_configure_class(options = {})
          write_inheritable_attribute(:acts_as_date_range_configuration, options)
          include InstanceMethods
        
          acts_as_date_range_sequentialize_class(options[:sequentialize]) if options[:sequentialize]
        end
      end
    end
  end
end
