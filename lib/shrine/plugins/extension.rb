class Shrine
  module Plugins
    # The extension plugin adds `#extension` method to your uploaded files.
    #
    #     plugin :extension
    #
    # The method returns the extension after the dot, and nil if there is no
    # extension:
    #
    #     uploader = Shrine.new(:store)
    #
    #     uploaded_file = uploader.upload(File.open("avatar.jpg"))
    #     uploaded_file.extension #=> "jpg"
    #
    #     uploaded_file = uploader.upload(File.open("avatar"))
    #     uploaded_file.extension #=> nil
    module Extension
      module FileMethods
        # Derives the extension from id, so that it works when there is no
        # \#original_filename.
        def extension
          extname = File.extname(id)
          extname[1..-1] unless extname.empty?
        end
      end
    end

    register_plugin(:extension, Extension)
  end
end
