module Centerstone #:nodoc:
  module AssociationExtensions
    module Ranged
    
      %w{before after containing contained_by overlapping}.each do |comparison|
        define_method comparison do |target|
          self.select { |x|  x.send((comparison + '?').to_sym,  target) }
        end
      end
      
    end
  end
end