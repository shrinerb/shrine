class Shrine
  module Plugins
    # The delete_invalid plugin allows you to delete the assigned attachment if
    # it was invalid.
    #
    #     plugin :delete_invalid
    #
    # By default the attachments is always cached before they're validated. This
    # way the attachment will persist when the form is resubmitted, like the
    # other fields in the form do.
    #
    # If you would prefer that invalid attachments don't stay in your cache,
    # you can use this plugin.
    module DeleteInvalid
      module AttacherMethods
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
