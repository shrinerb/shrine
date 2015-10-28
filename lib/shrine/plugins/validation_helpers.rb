class Shrine
  module Plugins
    # The validation_helpers plugin provides helper methods for validating
    # attached files.
    #
    #     class ImageUploader < Shrine
    #       plugin :validation_helpers
    #
    #       Attacher.validate do
    #         if record.guest?
    #           validate_max_size 5*1024*1024
    #         end
    #       end
    #     end
    #
    # The validation methods are instance-level, the `Attacher.validate` block
    # is evaluated in context of an instance of `Shrine::Attacher`, so you can
    # easily do conditional validation.
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
    #     validate_mime_type_inclusion [/^image/], message: "is not an image"
    #
    # For a complete list of all validation helpers, see AttacherMethods.
    module ValidationHelpers
      def self.configure(uploader, default_messages: {})
        uploader.opts[:validation_helpers_default_messages] = default_messages
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
            shrine_class.opts[:validation_helpers_default_messages])
        end
      end

      module AttacherMethods
        # Validates that the file is not larger than `max`.
        def validate_max_size(max, message: nil)
          if get.size > max
            errors << error_message(:max_size, message, max)
          end
        end

        # Validates that the file is not smaller than `min`.
        def validate_min_size(min, message: nil)
          if get.size < min
            errors << error_message(:min_size, message, min)
          end
        end

        # Validates that the file is not wider than `max`. Requires the
        # store_dimensions plugin.
        def validate_max_width(max, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:width)
          if get.width > max
            errors << error_message(:max_width, message, max)
          end
        end

        # Validates that the file is not narrower than `min`. Requires the
        # store_dimensions plugin.
        def validate_min_width(min, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:width)
          if get.width < min
            errors << error_message(:min_width, message, min)
          end
        end

        # Validates that the file is not taller than `max`. Requires the
        # store_dimensions plugin.
        def validate_max_height(max, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:height)
          if get.height > max
            errors << error_message(:max_height, message, max)
          end
        end

        # Validates that the file is not shorter than `min`. Requires the
        # store_dimensions plugin.
        def validate_min_height(min, message: nil)
          raise Error, ":store_dimensions plugin is required" if !get.respond_to?(:height)
          if get.height < min
            errors << error_message(:min_height, message, min)
          end
        end

        # Validates that the MIME type is in the `whitelist`. The whitelist is
        # an array of strings or regexes.
        #
        #     validate_mime_type_inclusion ["audio/mp3", /^video/]
        def validate_mime_type_inclusion(whitelist, message: nil)
          if whitelist.none? { |mime_type| regex(mime_type) =~ get.mime_type.to_s }
            errors << error_message(:mime_type_inclusion, message, whitelist)
          end
        end

        # Validates that the MIME type is not in the `blacklist`. The blacklist
        # is an array of strings or regexes.
        #
        #     validate_mime_type_exclusion ["image/gif", /^audio/]
        def validate_mime_type_exclusion(blacklist, message: nil)
          if blacklist.any? { |mime_type| regex(mime_type) =~ get.mime_type.to_s }
            errors << error_message(:mime_type_exclusion, message, blacklist)
          end
        end

        # Validates that the extension is in the `whitelist`. The whitelist
        # is an array of strings or regexes.
        #
        #     validate_extension_inclusion [/jpe?g/]
        def validate_extension_inclusion(whitelist, message: nil)
          if whitelist.none? { |extension| regex(extension) =~ get.extension.to_s }
            errors << error_message(:extension_inclusion, message, whitelist)
          end
        end

        # Validates that the extension is not in the `blacklist`. The blacklist
        # is an array of strings or regexes.
        #
        #     validate_extension_exclusion ["mov", /^mp*/]
        def validate_extension_exclusion(blacklist, message: nil)
          if blacklist.any? { |extension| regex(extension) =~ get.extension.to_s }
            errors << error_message(:extension_exclusion, message, blacklist)
          end
        end

        private

        # Converts a string to a regex.
        def regex(string)
          string.is_a?(Regexp) ? string : /^#{Regexp.escape(string)}$/
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
