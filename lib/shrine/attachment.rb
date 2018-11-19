# frozen_string_literal: true

class Shrine
  # Core class which creates attachment modules for specified attribute names
  # that are included into model classes.
  # Base implementation is defined in InstanceMethods and ClassMethods.
  class Attachment < Module
    @shrine_class = ::Shrine

    module ClassMethods
      # Returns the Shrine class that this attachment class is
      # namespaced under.
      attr_accessor :shrine_class

      # Since Attachment is anonymously subclassed when Shrine is subclassed,
      # and then assigned to a constant of the Shrine subclass, make inspect
      # reflect the likely name for the class.
      def inspect
        "#{shrine_class.inspect}::Attachment"
      end
    end

    module InstanceMethods
      # Instantiates an attachment module for a given attribute name, which
      # can then be included to a model class. Second argument will be passed
      # to an attacher module.
      def initialize(name, **options)
        @name    = name
        @options = options

        define_attachment_methods!
      end

      # Defines attachment methods for the specified attachment name. These
      # methods will be added to any model that includes this module.
      def define_attachment_methods!
        attachment    = self
        attacher_ivar = :"@#{@name}_attacher"

        define_method :"#{@name}_attacher" do |reload = false, **options|
          if reload || options.any? || !instance_variable_get(attacher_ivar)
            instance_variable_set(attacher_ivar, attachment.build_attacher(self, options))
          else
            instance_variable_get(attacher_ivar)
          end
        end

        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{@name}=(value)
            #{@name}_attacher.assign(value)
          end

          def #{@name}
            #{@name}_attacher.get
          end

          def #{@name}_url(*args)
            #{@name}_attacher.url(*args)
          end
        RUBY
      end

      # Creates an instance of the corresponding Attacher subclass.
      def build_attacher(object, options)
        shrine_class::Attacher.new(object, @name, @options.merge(options))
      end

      # Returns name of the attachment this module provides.
      def attachment_name
        @name
      end

      # Returns options that are to be passed to the Attacher.
      def options
        @options
      end

      # Returns class name with attachment name included.
      #
      #     Shrine[:image].to_s #=> "#<Shrine::Attachment(image)>"
      def to_s
        "#<#{self.class.inspect}(#{attachment_name})>"
      end

      # Returns class name with attachment name included.
      #
      #     Shrine[:image].inspect #=> "#<Shrine::Attachment(image)>"
      def inspect
        "#<#{self.class.inspect}(#{attachment_name})>"
      end

      # Returns the Shrine class that this attachment's class is namespaced
      # under.
      def shrine_class
        self.class.shrine_class
      end
    end
  end
end
