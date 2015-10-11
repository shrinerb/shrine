class Shrine
  module Plugins
    # The delete_invalid plugin immediately deletes the assigned attachment if
    # it failed validation.
    #
    #     plugin :delete_invalid
    #
    # By default an attachment is always cached before it's validated. This
    # way the attachment will persist when the form is resubmitted, which is
    # consistent with the other fields in the form. However, if this is a
    # concern, you can load this plugin.
    module DeleteInvalid
      module AttacherMethods
        # Delete the assigned uploaded file if it was invalid.
        def validate
          super
        ensure
          delete!(get, phase: :invalid) if !errors.empty?
        end
      end
    end

    register_plugin(:delete_invalid, DeleteInvalid)
  end
end
