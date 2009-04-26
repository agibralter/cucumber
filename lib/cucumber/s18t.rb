require 'singleton'

module Cucumber
  
  class S18tHelper
    include Singleton
    
    def is_negative?
      @is_negative === true
    end
    
    def is_negative
      @is_negative = true
    end
    
    def is_positive
      @is_positive = false
    end
  end
  
  module S18t
    def s18t(*args)
      if S18tHelper.instance.is_negative?
        self.send(:should_not, *args)
      else
        self.send(:should, *args)
      end
    end
  end
end

class Object
  include Cucumber::S18t
end
