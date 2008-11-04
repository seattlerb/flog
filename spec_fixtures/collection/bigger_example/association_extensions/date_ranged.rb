module Centerstone #:nodoc:
  module AssociationExtensions
    module DateRanged
      
      def current
        containing(Time.now)
      end
      
    end
  end
end