require "test_helper"
require "shrine/plugins/hooks"

describe Shrine::Plugins::Hooks do
  before do
    @uploader = uploader { plugin :hooks }
  end

  it "provides uploading hooks" do
    @uploader.instance_variable_set("@hooks", [])
    @uploader.instance_eval do
      def before_upload(io, context)
        @hooks << "before_upload"
        super
      end

      def around_upload(io, context)
        @hooks << "before around_upload"
        super
        @hooks << "after around_upload"
      end

      def before_process(io, context)
        @hooks << "before_process"
        super
      end

      def around_process(io, context)
        @hooks << "before around_process"
        super
        @hooks << "after around_process"
      end

      def after_process(io, context)
        super
        @hooks << "after_process"
      end

      def before_store(io, context)
        @hooks << "before_store"
        super
      end

      def around_store(io, context)
        @hooks << "before around_store"
        super
        @hooks << "after around_store"
      end

      def after_store(io, context)
        super
        @hooks << "after_store"
      end

      def after_upload(io, context)
        super
        @hooks << "after_upload"
      end
    end

    result = @uploader.upload(fakeio)

    assert_kind_of Shrine::UploadedFile, result
    assert_equal \
      [
        "before_upload",
        "before around_upload",
          "before_process",
          "before around_process",
          "after around_process",
          "after_process",

          "before_store",
          "before around_store",
          "after around_store",
          "after_store",
        "after around_upload",
        "after_upload",
      ],
      @uploader.instance_variable_get("@hooks")
  end

  it "provides deleting hooks" do
    @uploader.instance_variable_set("@hooks", [])
    @uploader.instance_eval do
      def before_delete(io, context)
        @hooks << "before_delete"
        super
      end

      def around_delete(io, context)
        @hooks << "before around_delete"
        super
        @hooks << "after around_delete"
      end

      def after_delete(io, context)
        super
        @hooks << "after_delete"
      end
    end

    uploaded_file = @uploader.upload(fakeio)
    result = @uploader.delete(uploaded_file)

    assert_kind_of Shrine::UploadedFile, result
    assert_equal \
      [
        "before_delete",
        "before around_delete",
        "after around_delete",
        "after_delete",
      ],
      @uploader.instance_variable_get("@hooks")
  end

  it "returns the result in around hooks" do
    @uploader.instance_eval do
      def process(io, context)
        io
      end

      def around_upload(io, context)
        raise "not in around_upload" unless super.is_a?(Shrine::UploadedFile)
      end

      def around_process(io, context)
        raise "not in around_process" unless super == io
      end

      def around_store(io, context)
        raise "not in around_store" unless super.is_a?(Shrine::UploadedFile)
      end

      def around_delete(io, context)
        raise "not in around_delete" unless super == io
      end
    end

    @uploader.upload(fakeio)
  end
end
