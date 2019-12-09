require "test_helper"
require "shrine/plugins/type_predicates"

describe Shrine::Plugins::TypePredicates do
  MIME_DATABASES = Shrine::Plugins::TypePredicates::MimeDatabase::SUPPORTED_TOOLS

  before do
    @uploader      = uploader { plugin :type_predicates }
    @shrine        = @uploader.class
    @uploaded_file = @uploader.upload(fakeio)
  end

  describe "UploadedFile" do
    describe "#image?" do
      it "returns true when mime type is image" do
        @uploaded_file.metadata["mime_type"] = "image/jpeg"
        assert @uploaded_file.image?
      end

      it "returns false when mime type is not image" do
        @uploaded_file.metadata["mime_type"] = "video/mp4"
        refute @uploaded_file.image?
      end
    end

    describe "#video?" do
      it "returns true when mime type is video" do
        @uploaded_file.metadata["mime_type"] = "video/mp4"
        assert @uploaded_file.video?
      end

      it "returns false when mime type is not video" do
        @uploaded_file.metadata["mime_type"] = "image/jpeg"
        refute @uploaded_file.video?
      end
    end

    describe "#video?" do
      it "returns true when mime type is audio" do
        @uploaded_file.metadata["mime_type"] = "audio/mp3"
        assert @uploaded_file.audio?
      end

      it "returns false when mime type is not audio" do
        @uploaded_file.metadata["mime_type"] = "image/jpeg"
        refute @uploaded_file.audio?
      end
    end

    describe "#text?" do
      it "returns true when mime type is text" do
        @uploaded_file.metadata["mime_type"] = "text/csv"
        assert @uploaded_file.text?
      end

      it "returns false when mime type is not text" do
        @uploaded_file.metadata["mime_type"] = "image/jpeg"
        refute @uploaded_file.text?
      end
    end

    describe "#type?" do
      it "returns whether associated MIME type matches current" do
        @uploaded_file.metadata["mime_type"] = "image/jpeg"

        assert_equal true,  @uploaded_file.type?(:jpg)
        assert_equal false, @uploaded_file.type?(:png)
      end

      it "raises exception when mime_type metadata is missing" do
        @uploaded_file.metadata["mime_type"] = nil

        assert_raises Shrine::Error do
          @uploaded_file.type?(:jpg)
        end
      end

      it "raises exception when extension is not recognized" do
        assert_raises Shrine::Error do
          @uploaded_file.type?(:foo)
        end
      end
    end

    describe "type methods" do
      it "returns whether associated MIME type matches current" do
        @shrine.plugin :type_predicates, methods: %i[jpg png]

        @uploaded_file.metadata["mime_type"] = "image/jpeg"

        assert_equal true,  @uploaded_file.jpg?
        assert_equal false, @uploaded_file.png?
      end
    end
  end

  describe "Shrine" do
    describe ".type_lookup" do
      it "returns MIME type for default MIME database" do
        assert_equal "image/jpeg",    @shrine.type_lookup(:jpg)
        assert_equal "image/svg+xml", @shrine.type_lookup(:svg)

        assert_nil @shrine.type_lookup(:foo)
      end

      MIME_DATABASES.each do |database|
        it "returns MIME type for #{database.inspect} database" do
          @shrine.plugin :type_predicates, mime: database

          assert_equal "image/jpeg",    @shrine.type_lookup(:jpg)
          assert_equal "image/svg+xml", @shrine.type_lookup(:svg)

          assert_nil @shrine.type_lookup(:foo)
        end
      end

      it "returns MIME Type for custom database" do
        @shrine.plugin :type_predicates, mime: -> (extension) { extension }

        assert_equal "jpg", @shrine.type_lookup(:jpg)
        assert_equal "svg", @shrine.type_lookup(:svg)
        assert_equal "foo", @shrine.type_lookup(:foo)
      end

      it "raises an error for unsupported MIME database" do
        @shrine.plugin :type_predicates, mime: :foo

        assert_raises Shrine::Error do
          @shrine.type_lookup(:jpg)
        end
      end
    end
  end
end
