require "test_helper"

describe "hooks plugin" do
  before do
    @uploader = uploader { plugin :hooks }
  end

  it "provides uploading hooks" do
    @uploader.instance_eval do
      def around_process(io, context)
        @hooks = []
        @hooks << "before around_process"
        super
        @hooks << "after around_process"
      end

      def before_process(io, context)
        @hooks << "before_process"
        super
      end

      def after_process(io, context)
        super
        @hooks << "after_process"
      end


      def around_store(io, context)
        @hooks << "before around_store"
        super
        @hooks << "after around_store"
      end

      def before_store(io, context)
        @hooks << "before_store"
        super
      end

      def after_store(io, context)
        super
        @hooks << "after_store"
      end
    end

    result = @uploader.upload(fakeio)

    assert_kind_of Shrine::UploadedFile, result
    assert_equal \
      [
        "before around_process",
        "before_process",
        "after_process",
        "after around_process",
        "before around_store",
        "before_store",
        "after_store",
        "after around_store",
      ],
      @uploader.instance_variable_get("@hooks")
  end

  it "provides deleting hooks" do
    @uploader.instance_eval do
      def around_delete(io, context)
        @hooks = []
        @hooks << "before around_delete"
        super
        @hooks << "after around_delete"
      end

      def before_delete(io, context)
        @hooks << "before_delete"
        super
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
        "before around_delete",
        "before_delete",
        "after_delete",
        "after around_delete",
      ],
      @uploader.instance_variable_get("@hooks")
  end
end
