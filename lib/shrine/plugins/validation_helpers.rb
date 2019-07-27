# frozen_string_literal: true

class Shrine
  module Plugins
    # Documentation lives in [doc/plugins/validation_helpers.md] on GitHub.
    #
    # [doc/plugins/validation_helpers.md]: https://github.com/shrinerb/shrine/blob/master/doc/plugins/validation_helpers.md
    module ValidationHelpers
      def self.load_dependencies(uploader, *)
        uploader.plugin :validation
      end

      def self.configure(uploader, opts = {})
        uploader.opts[:validation_default_messages] ||= {}
        uploader.opts[:validation_default_messages].merge!(opts[:default_messages] || {})
      end

      DEFAULT_MESSAGES = {
        max_size:            -> (max)  { "size must not be greater than #{PRETTY_FILESIZE.call(max)}" },
        min_size:            -> (min)  { "size must not be less than #{PRETTY_FILESIZE.call(min)}" },
        max_width:           -> (max)  { "width must not be greater than #{max}px" },
        min_width:           -> (min)  { "width must not be less than #{min}px" },
        max_height:          -> (max)  { "height must not be greater than #{max}px" },
        min_height:          -> (min)  { "height must not be less than #{min}px" },
        max_dimensions:      -> (dims) { "dimensions must not be greater than #{dims.join("x")}" },
        min_dimensions:      -> (dims) { "dimensions must not be less than #{dims.join("x")}" },
        mime_type_inclusion: -> (list) { "type must be one of: #{list.join(", ")}" },
        mime_type_exclusion: -> (list) { "type must not be one of: #{list.join(", ")}" },
        extension_inclusion: -> (list) { "extension must be one of: #{list.join(", ")}" },
        extension_exclusion: -> (list) { "extension must not be one of: #{list.join(", ")}" },
      }

      FILESIZE_UNITS = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"].freeze

      # Returns filesize in a human readable format with units.
      # Uses the binary JEDEC unit system, i.e. 1.0 KB = 1024 bytes
      PRETTY_FILESIZE = lambda do |bytes|
        return "0.0 B" if bytes == 0

        exp = Math.log(bytes, 1024).floor
        max_exp = FILESIZE_UNITS.length - 1
        exp = max_exp if exp > max_exp
        "%.1f %s" % [bytes.to_f / 1024 ** exp, FILESIZE_UNITS[exp]]
      end

      module AttacherClassMethods
        def default_validation_messages
          @default_validation_messages ||= DEFAULT_MESSAGES.merge(
            shrine_class.opts[:validation_default_messages])
        end
      end

      module AttacherMethods
        # Validates that the `size` metadata is not larger than `max`.
        #
        #     validate_max_size 5*1024*1024
        def validate_max_size(max, message: nil)
          validate_result(file.size <= max, :max_size, message, max)
        end

        # Validates that the `size` metadata is not smaller than `min`.
        #
        #     validate_min_size 1024
        def validate_min_size(min, message: nil)
          validate_result(file.size >= min, :min_size, message, min)
        end

        # Validates that the `size` metadata is in the given range.
        #
        #     validate_size 1024..5*1024*1024
        def validate_size(size_range)
          min_size, max_size = size_range.begin, size_range.end

          validate_min_size(min_size) && validate_max_size(max_size)
        end


        # Validates that the `width` metadata is not larger than `max`.
        # Requires the `store_dimensions` plugin.
        #
        #     validate_max_width 5000
        def validate_max_width(max, message: nil)
          fail Error, "width metadata is missing" unless file["width"]

          validate_result(file["width"] <= max, :max_width, message, max)
        end

        # Validates that the `width` metadata is not smaller than `min`.
        # Requires the `store_dimensions` plugin.
        #
        #     validate_min_width 100
        def validate_min_width(min, message: nil)
          fail Error, "width metadata is missing" unless file["width"]

          validate_result(file["width"] >= min, :min_width, message, min)
        end

        # Validates that the `width` metadata is in the given range.
        #
        #     validate_width 100..5000
        def validate_width(width_range)
          min_width, max_width = width_range.begin, width_range.end

          validate_min_width(min_width) && validate_max_width(max_width)
        end


        # Validates that the `height` metadata is not larger than `max`.
        # Requires the `store_dimensions` plugin.
        #
        #     validate_max_height 5000
        def validate_max_height(max, message: nil)
          fail Error, "height metadata is missing" unless file["height"]

          validate_result(file["height"] <= max, :max_height, message, max)
        end

        # Validates that the `height` metadata is not smaller than `min`.
        # Requires the `store_dimensions` plugin.
        #
        #     validate_min_height 100
        def validate_min_height(min, message: nil)
          fail Error, "height metadata is missing" unless file["height"]

          validate_result(file["height"] >= min, :min_height, message, min)
        end

        # Validates that the `height` metadata is in the given range.
        #
        #     validate_height 100..5000
        def validate_height(height_range)
          min_height, max_height = height_range.begin, height_range.end

          validate_min_height(min_height) && validate_max_height(max_height)
        end

        # Validates that the dimensions are not larger than specified.
        #
        #     validate_max_dimensions [5000, 5000]
        def validate_max_dimensions((max_width, max_height), message: nil)
          fail Error, "width and/or height metadata is missing" unless file["width"] && file["height"]

          validate_result(
            file["width"] <= max_width && file["height"] <= max_height,
            :max_dimensions, message, [max_width, max_height]
          )
        end

        # Validates that the dimensions are not smaller than specified.
        #
        #     validate_max_dimensions [100, 100]
        def validate_min_dimensions((min_width, min_height), message: nil)
          fail Error, "width and/or height metadata is missing" unless file["width"] && file["height"]

          validate_result(
            file["width"] >= min_width && file["height"] >= min_height,
            :min_dimensions, message, [min_width, min_height]
          )
        end

        # Validates that the dimensions are in the given range.
        #
        #     validate_dimensions [100..5000, 100..5000]
        def validate_dimensions((width_range, height_range))
          min_dims = width_range.begin, height_range.begin
          max_dims = width_range.end,   height_range.end

          validate_min_dimensions(min_dims) && validate_max_dimensions(max_dims)
        end

        # Validates that the `mime_type` metadata is included in the given
        # list.
        #
        #     validate_mime_type_inclusion %w[audio/mp3 audio/flac]
        def validate_mime_type_inclusion(types, message: nil)
          validate_result(
            types.include?(file.mime_type),
            :mime_type_inclusion, message, types
          )
        end
        alias validate_mime_type validate_mime_type_inclusion

        # Validates that the `mime_type` metadata is not included in the given
        # list.
        #
        #     validate_mime_type_exclusion %w[text/x-php]
        def validate_mime_type_exclusion(types, message: nil)
          validate_result(
            !types.include?(file.mime_type),
            :mime_type_exclusion, message, types
          )
        end

        # Validates that the extension is included in the given list.
        # Comparison is case insensitive.
        #
        #     validate_extension_inclusion %w[jpg jpeg png gif]
        def validate_extension_inclusion(extensions, message: nil)
          validate_result(
            extensions.any? { |extension| extension.casecmp(file.extension.to_s) == 0 },
            :extension_inclusion, message, extensions
          )
        end
        alias validate_extension validate_extension_inclusion

        # Validates that the extension is not included in the given list.
        # Comparison is case insensitive.
        #
        #     validate_extension_exclusion %[php jar]
        def validate_extension_exclusion(extensions, message: nil)
          validate_result(
            extensions.none? { |extension| extension.casecmp(file.extension.to_s) == 0 },
            :extension_exclusion, message, extensions
          )
        end

        private

        # Adds an error if result is false and returns the result.
        def validate_result(result, type, message, *args)
          if result
            true
          else
            add_error(type, message, *args)
            false
          end
        end

        # Generates an error message and appends it to errors array.
        def add_error(*args)
          errors << error_message(*args)
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
