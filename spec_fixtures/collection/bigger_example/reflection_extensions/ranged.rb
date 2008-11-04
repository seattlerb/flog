module Centerstone #:nodoc:
  module ReflectionExtensions
    module Ranged
      
      def self.included(base)
        puts 'hello'
        base.send(:include,  InstanceMethods)
        
        base.instance_eval do
          alias_method_chain :initialize, :has_many_range_extension
        end
      end
      
      module InstanceMethods
        def initialize_with_has_many_range_extension(*args)
          puts 'yo'
          returning initialize_without_has_many_range_extension(*args) do
            puts 'returning stuff'
            if macro.to_s == 'has_many'
              puts 'adding the extension'
              add_has_many_range_extension
            end
            puts 'blah'
          end
        end
        
        private
        
        def add_has_many_range_extension
          puts 'extension adding, hey'
          puts 'bbbbb'
          puts "target class [#{klass}]"
          if klass.acts_as_range?
            puts 'target acts as range'
            extension = Centerstone::AssociationExtensions::Ranged
            opts = options
            
            opts[:extend] ||= []
            opts[:extend] = [opts[:extend]].flatten
            
            opts[:extend].push(extension) unless opts[:extend].include?(extension)
            
            @options = opts
          end
        end
      end
      
    end
  end
end