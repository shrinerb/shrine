# frozen_string_literal: true

class Shrine
  module Plugins
    module Validation
      module AttacherClassMethods
        # Block that is executed in context of Shrine::Attacher during
        # validation. Example:
        #
        #     Shrine::Attacher.validate do
        #       if file.size > 5*1024*1024
        #         errors << "is too big (max is 5 MB)"
        #       end
        #     end
        def validate(&block)
          private define_method(:validate_block, &block)
        end
      end

      module AttacherMethods
        # Returns an array of validation errors created on file assignment in
        # the `Attacher.validate` block.
        attr_reader :errors

        # Initializes validation errors to an empty array.
        def initialize(**options)
          super
          @errors = []
        end

        # Leaves out :validate option when calling `Shrine.upload`.
        def upload(*args, validate: nil, **options)
          super(*args, **options)
        end

        # Performs validations after changing the file.
        def change(file, validate: nil, **)
          result = super
          validation(validate)
          result
        end

        # Runs the validation defined by `Attacher.validate`.
        def validate(**options)
          errors.clear
          _validate(**options) if attached?
        end

        private

        # Calls validation appropriately based on the :validate value.
        def validation(argument)
          case argument
          when Hash  then validate(argument)
          when false then errors.clear # skip validation
          else            validate
          end
        end

        # Calls #validate_block, passing it accepted parameters.
        def _validate(**options)
          if method(:validate_block).arity.zero?
            validate_block
          else
            validate_block(**options)
          end
        end

        # Overridden by the `Attacher.validate` block.
        def validate_block(**options)
        end
      end
    end

    register_plugin(:validation, Validation)
  end
end
