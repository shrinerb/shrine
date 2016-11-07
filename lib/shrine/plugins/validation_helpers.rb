class Shrine
  module Plugins
    # The `validation_helpers` plugin provides helper methods for validating
    # attached files.
    #
    #     plugin :validation_helpers
    #
    #     Attacher.validate do
    #       validat_mime_type_inclusion %w[image/jpeg image/png image/gif]
    #       validate_max_size 5*1024*1024 if record.guest?
    #     end
    #
    # The validation methods are instance-level, the `Attacher.validate` block
    # is evaluated in context of an instance of `Shrine::Attacher`, so you can
    # easily do conditional validation.
    #
    # The validation methods return whether the validation succeeded, allowing
    # you to do conditional validation.
    #
    #     if validate_mime_type_inclusion %w[image/jpeg image/png image/gif]
    #       validate_max_width 2000
    #       validate_max_height 2000
    #     end
    #
    # If you would like to change default validation error messages, you can
    # pass in the `:default_messages` option to the plugin:
    #
    #     plugin :validation_helpers, default_messages: {
    #       max_size: ->(max) { I18n.t("errors.file.max_size", max: max) },
    #       mime_type_inclusion: ->(whitelist) { I18n.t("errors.file.mime_type_inclusion", whitelist: whitelist) },
    #     }
    #
    # If you would like to change the error message inline, you can pass the
    # `:message` option to any validation method:
    #
    #     validate_mime_type_inclusion [/\Aimage/], message: "is not an image"
    #
    # For a complete list of all validation helpers, see AttacherMethods.
    module ValidationHelpers
      def self.configure(uploader, opts = {})
        uploader.opts[:validation_default_messages] = (uploader.opts[:validation_default_messages] || {}).merge(opts[:default_messages] || {})
      end

      DEFAULT_MESSAGES = {
        max_size: ->(max) { "is larger than #{max.to_f/1024/1024} MB" },
        min_size: ->(min) { "is smaller than #{min.to_f/1024/1024} MB" },
        max_width: ->(max) { "is wider than #{max} px" },
        min_width: ->(min) { "is narrower than #{min} px" },
        max_height: ->(max) { "is taller than #{max} px" },
        min_height: ->(min) { "is shorter than #{min} px" },
        mime_type_inclusion: ->(list) { "isn't of allowed type: #{list.inspect}" },
        mime_type_exclusion: ->(list) { "is of forbidden type: #{list.inspect}" },
        extension_inclusion: ->(list) { "isn't in allowed format: #{list.inspect}" },
        extension_exclusion: ->(list) { "is in forbidden format: #{list.inspect}" },
      }

      module AttacherClassMethods
        def default_validation_messages
          @default_validation_messages ||= DEFAULT_MESSAGES.merge(
            shrine_class.opts[:validation_default_messages])
        end
      end

      module AttacherMethods
        # Validates that the file is not larger than `max`.
        def validate_max_size(max, message: nil)
          get.size <= max or errors << error_message(:max_size, message, max) && false
        end

        # Validates that the file is not smaller than `min`.
        def validate_min_size(min, message: nil)
          get.size >= min or errors << error_message(:min_size, message, min) && false
        end

        # Validates that the file is not wider than `max`. Requires the
        # `store_dimensions` plugin.
        def validate_max_width(max, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:width)
          get.width <= max or errors << error_message(:max_width, message, max) && false if get.width
        end

        # Validates that the file is not narrower than `min`. Requires the
        # `store_dimensions` plugin.
        def validate_min_width(min, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:width)
          get.width >= min or errors << error_message(:min_width, message, min) && false if get.width
        end

        # Validates that the file is not taller than `max`. Requires the
        # `store_dimensions` plugin.
        def validate_max_height(max, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:height)
          get.height <= max or errors << error_message(:max_height, message, max) && false if get.height
        end

        # Validates that the file is not shorter than `min`. Requires the
        # `store_dimensions` plugin.
        def validate_min_height(min, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:height)
          get.height >= min or errors << error_message(:min_height, message, min) && false if get.height
        end

        # Validates that the MIME type is in the `whitelist`. The whitelist is
        # an array of strings or regexes.
        #
        #     validate_mime_type_inclusion ["audio/mp3", /\Avideo/]
        def validate_mime_type_inclusion(whitelist, message: nil)
          whitelist.any? { |mime_type| regex(mime_type) =~ get.mime_type.to_s } \
            or errors << error_message(:mime_type_inclusion, message, whitelist) && false
        end

        # Validates that the MIME type is not in the `blacklist`. The blacklist
        # is an array of strings or regexes.
        #
        #     validate_mime_type_exclusion ["image/gif", /\Aaudio/]
        def validate_mime_type_exclusion(blacklist, message: nil)
          blacklist.none? { |mime_type| regex(mime_type) =~ get.mime_type.to_s } \
            or errors << error_message(:mime_type_exclusion, message, blacklist) && false
        end

        # Validates that the extension is in the `whitelist`. The whitelist
        # is an array of strings or regexes.
        #
        #     validate_extension_inclusion [/\Ajpe?g\z/i]
        def validate_extension_inclusion(whitelist, message: nil)
          whitelist.any? { |extension| regex(extension) =~ get.extension.to_s } \
            or errors << error_message(:extension_inclusion, message, whitelist) && false
        end

        # Validates that the extension is not in the `blacklist`. The blacklist
        # is an array of strings or regexes.
        #
        #     validate_extension_exclusion ["mov", /\Amp/i]
        def validate_extension_exclusion(blacklist, message: nil)
          blacklist.none? { |extension| regex(extension) =~ get.extension.to_s } \
            or errors << error_message(:extension_exclusion, message, blacklist) && false
        end

        private

        # Converts a string to a regex.
        def regex(value)
          value.is_a?(Regexp) ? value : /\A#{Regexp.escape(value)}\z/i
        end

        # Returns the direct message if given, otherwise uses the default error
        # message.
        def error_message(type, message, object)
          message ||= self.class.default_validation_messages.fetch(type)
          message.is_a?(String) ? message : message.call(object)
        end
      end
    end

    register_plugin(:validation_helpers, ValidationHelpers)
  end
end
