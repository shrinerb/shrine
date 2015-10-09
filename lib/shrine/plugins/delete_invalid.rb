class Shrine
  module Plugins
    # The delete_invalid plugin deletes assigned attachments that failed
    # validation.
    #
    #     plugin :delete_invalid
    #
    # By default an attachment is always cached before it's validated. This
    # way the attachment will persist when the form is resubmitted, which is
    # consistent with the other fileds in the form.
    #
    # You can use this plugin if you prefer that invalid attachments are
    # immediately deleted.
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
