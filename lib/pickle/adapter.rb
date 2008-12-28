module Pickle
  # Abstract Factory adapter class, if you have a factory type setup, you
  # can easily create an adaptor to make it work with Pickle.
  #
  # The factory adaptor must have a #factories class method that returns 
  # its instances, and each instance must respond to a #name method which
  # identifies the factory by name (default is attr_reader for @name), and a
  # #create method which takes an optional attributes hash,
  # and returns a newly created object
  class Adapter
    attr_reader :name
    
    def self.factories_hash
      factories.inject({}) {|hash, factory| hash.merge(factory.name => factory)}
    end
    
    def self.factories
      raise NotImplementedError, "return an array of factory adapter objects"
    end
  
    def create(attrs = {})
      raise NotImplementedError, "create and return an object with the given attributes"
    end
    
    # machinist adapter
    class Machinist < Adapter
      def self.factories
        ::ActiveRecord::Base.send(:subclasses).map do |klass|
          klass.methods.select{|m| m =~ /^make/}.map do |method|
            new(klass, method) unless method =~ /_unsaved$/
          end
        end.flatten
      end
      
      def initialize(klass, method)
        @klass, @method = klass, method
        @name = @klass.name.underscore.gsub('/','_')
        @name = "#{@method.sub('make_','')}_#{@name}" unless @method == 'make'
      end
      
      def create(attrs = {})
        @klass.send(@method, attrs)
      end
    end
    
    # factory-girl adapter
    class FactoryGirl < Adapter
      def self.factories
        (::Factory.factories.keys rescue []).map {|key| new(key)}
      end
      
      def initialize(key)
        @name = key.to_s
      end
    
      def create(attrs = {})
        ::Factory.send(@name, attrs)
      end
    end
        
    # fallback active record adapter
    class ActiveRecord < Adapter
      def self.factories
        ::ActiveRecord::Base.send(:subclasses).map {|klass| new(klass) }
      end

      def initialize(klass)
        @klass, @name = klass, klass.name.underscore.gsub('/','_')
      end

      def create(attrs = {})
        @klass.send(:create!, attrs)
      end
    end
  end
end