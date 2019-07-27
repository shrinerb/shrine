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
          private define_method(:_validate, &block)
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
          @validate_options = {}
        end

        # Registers options that will be passed to validation.
        def validate_options(options)
          @validate_options.merge!(options)
        end

        # Leaves out :validate option when calling `Shrine.upload`.
        def upload(io, storage, validate: nil, **options)
          super(io, storage, **options)
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
          return unless attached?

          if method(:_validate).arity.zero?
            _validate
          else
            _validate(**@validate_options, **options)
          end
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

        # Overridden by the `Attacher.validate` block.
        def _validate(**options)
        end
      end
    end

    register_plugin(:validation, Validation)
  end
end
