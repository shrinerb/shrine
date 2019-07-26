require "test_helper"
require "shrine/plugins/versions"

describe Shrine::Plugins::Versions do
  before do
    @attacher = attacher { plugin :versions }
    @shrine   = @attacher.shrine_class
    @uploader = @attacher.store
  end

  describe "Shrine" do
    describe "#upload" do
      it "accepts versions" do
        versions = @uploader.upload(thumb: fakeio)
        assert_kind_of Shrine::UploadedFile, versions.fetch(:thumb)

        versions = @uploader.upload([fakeio])
        assert_kind_of Shrine::UploadedFile, versions.fetch(0)

        versions = @uploader.upload(thumb: [fakeio])
        assert_kind_of Shrine::UploadedFile, versions.fetch(:thumb).fetch(0)

        # uploading a single file still works
        file = @uploader.upload(fakeio)
        assert_kind_of Shrine::UploadedFile, file
      end

      it "coerces version names into symbols" do
        @shrine.process(:store) { |io| { "name" => io } }

        versions = @uploader.upload(fakeio, action: :store)

        assert versions.key?(:name)
        assert versions.fetch(:name).exists?
      end

      it "allows processing into versions" do
        @uploader.instance_eval { def process(io, **); {thumb: io}; end }
        versions = @uploader.upload(fakeio("file"))
        assert_equal "file", versions.fetch(:thumb).read

        @uploader.instance_eval { def process(io, **); [io]; end }
        versions = @uploader.upload(fakeio("file"))
        assert_equal "file", versions.fetch(0).read

        @uploader.instance_eval { def process(io, **); {thumb: [io]}; end }
        versions = @uploader.upload(fakeio("file"))
        assert_equal "file", versions.fetch(:thumb).fetch(0).read

        # processing into single file still works
        @uploader.instance_eval { def process(io, **); io; end }
        file = @uploader.upload(fakeio("file"))
        assert_equal "file", file.read
      end

      it "allows reprocessing versions" do
        @uploader.instance_eval { def process(hash, context); {thumb: hash.fetch(:thumb)}; end }
        versions = @uploader.upload(thumb: fakeio("thumb"))
        assert_equal "thumb", versions.fetch(:thumb).read

        @uploader.instance_eval { def process(array, context); [array.fetch(0)]; end }
        versions = @uploader.upload([fakeio("thumb")])
        assert_equal "thumb", versions.fetch(0).read

        @uploader.instance_eval { def process(nested, context); {thumb: nested.fetch(:thumb)}; end }
        versions = @uploader.upload(thumb: [fakeio("thumb")])
        assert_equal "thumb", versions.fetch(:thumb).fetch(0).read
      end

      it "passes the version name to location generator" do
        @uploader.instance_eval { def generate_location(io, version:, **); version.to_s; end }
        versions = @uploader.upload(thumb: fakeio)
        assert_equal "thumb", versions.fetch(:thumb).id

        @uploader.instance_eval { def generate_location(io, version:, **); version.to_s; end }
        versions = @uploader.upload([fakeio])
        assert_equal "0", versions.fetch(0).id

        @uploader.instance_eval { def generate_location(io, version:, **); version.to_s; end }
        versions = @uploader.upload(thumb: [fakeio])
        assert_equal "[:thumb, 0]", versions.fetch(:thumb).fetch(0).id

        # doesn't pass it in case of a single file
        @uploader.instance_eval { def generate_location(io, options); options.key?(:version).to_s; end }
        file = @uploader.upload(fakeio)
        assert_equal "false", file.id
      end

      it "still catches invalid IOs" do
        @uploader.instance_eval { def process(io, context); {thumb: "invalid IO"}; end }
        error = assert_raises(Shrine::InvalidFile) { @uploader.upload(fakeio) }
        assert_match /is not a valid IO object/, error.message
      end
    end

    describe ".uploaded_file" do
      it "recognizes versions" do
        uploaded_file = @uploader.upload(fakeio)
        retrieved = @uploader.class.uploaded_file("thumb" => uploaded_file.data)
        assert_equal Hash[thumb: uploaded_file], retrieved

        uploaded_file = @uploader.upload(fakeio)
        retrieved = @uploader.class.uploaded_file([uploaded_file.data])
        assert_equal [uploaded_file], retrieved

        uploaded_file = @uploader.upload(fakeio)
        retrieved = @uploader.class.uploaded_file(thumb: [uploaded_file.data])
        assert_equal Hash[thumb: [uploaded_file]], retrieved

        # still recognizes single file
        uploaded_file = @uploader.upload(fakeio)
        retrieved = @uploader.class.uploaded_file(uploaded_file.data)
        assert_equal uploaded_file, retrieved
      end
    end
  end

  describe "Attacher" do
    describe "#assign" do
      it "assigns versions" do
        versions = {thumb: @shrine.upload(fakeio, :cache)}
        @attacher.assign(versions.to_json)
        assert_equal versions, @attacher.file

        versions = [@shrine.upload(fakeio, :cache)]
        @attacher.assign(versions.to_json)
        assert_equal versions, @attacher.file

        file = @shrine.upload(fakeio, :cache)
        @attacher.assign(file.to_json)
        assert_equal file, @attacher.file
      end
    end

    describe "#destroy_attached" do
      it "deletes versions" do
        @attacher.set(thumb: @uploader.upload(fakeio))
        @attacher.destroy_attached
        refute @attacher.get[:thumb].exists?

        @attacher.set([@uploader.upload(fakeio)])
        @attacher.destroy_attached
        refute @attacher.get[0].exists?

        @attacher.set(thumb: [@uploader.upload(fakeio)])
        @attacher.destroy_attached
        refute @attacher.get[:thumb][0].exists?

        @attacher.set(@uploader.upload(fakeio))
        @attacher.destroy_attached
        refute @attacher.file.exists?
      end
    end

    describe "#destroy_previous" do
      it "deletes versions" do
        @attacher.change(original = {thumb: @uploader.upload(fakeio)})
        @attacher.change(thumb: @uploader.upload(fakeio))
        @attacher.destroy_previous
        refute original[:thumb].exists?

        @attacher.change(original = [@uploader.upload(fakeio)])
        @attacher.change([@uploader.upload(fakeio)])
        @attacher.destroy_previous
        refute original[0].exists?

        @attacher.change(original = {thumb: [@uploader.upload(fakeio)]})
        @attacher.change(thumb: [@uploader.upload(fakeio)])
        @attacher.destroy_previous
        refute original[:thumb][0].exists?

        @attacher.change(original = @uploader.upload(fakeio))
        @attacher.change(@uploader.upload(fakeio))
        @attacher.destroy_previous
        refute original.exists?
      end
    end

    describe "#promote_cached" do
      it "promotes versions successfully" do
        @attacher.change(thumb: @shrine.upload(fakeio, :cache))
        @attacher.promote_cached
        assert_equal :store, @attacher.get[:thumb].storage_key

        @attacher.change([@shrine.upload(fakeio, :cache)])
        @attacher.promote_cached
        assert_equal :store, @attacher.get[0].storage_key

        @attacher.change(thumb: [@shrine.upload(fakeio, :cache)])
        @attacher.promote_cached
        assert_equal :store, @attacher.get[:thumb][0].storage_key

        @attacher.change(@shrine.upload(fakeio, :cache))
        @attacher.promote_cached
        assert_equal :store, @attacher.file.storage_key
      end
    end

    describe "#url" do
      it "accepts a version name indifferently" do
        @attacher.set(thumb: @uploader.upload(fakeio))
        assert_equal @attacher.get[:thumb].url, @attacher.url(:thumb)
        assert_equal @attacher.get[:thumb].url, @attacher.url("thumb")
      end

      it "returns nil when a attachment doesn't exist" do
        assert_nil @attacher.url(:thumb)
      end

      it "doesn't fail if version is registered but missing" do
        @attacher.set({})
        @attacher.class.default_url { |options| "missing #{options[:version]}" }
        assert_equal "missing thumb", @attacher.url(:thumb)
      end

      it "returns raw file URL if versions haven't been generated" do
        @attacher.assign(fakeio)
        assert_equal @attacher.url, @attacher.url(:thumb)
      end

      it "doesn't allow no argument when attachment is versioned" do
        @attacher.set(thumb: @uploader.upload(fakeio))
        assert_raises(Shrine::Error) { @attacher.url }
      end

      it "passes in :version to the default url" do
        @attacher.class.default_url { |options| "missing #{options[:version]}" }
        assert_equal "missing thumb", @attacher.url(:thumb)
      end

      it "forwards url options" do
        @attacher.set(thumb: @uploader.upload(fakeio))
        Shrine::UploadedFile.any_instance.expects(:url).with(foo: "foo")
        @attacher.url(:thumb, foo: "foo")
        @attacher.set(@uploader.upload(fakeio))
        Shrine::UploadedFile.any_instance.expects(:url).with(foo: "foo")
        @attacher.url(:thumb, foo: "foo")
        Shrine::UploadedFile.any_instance.expects(:url).with(foo: "foo")
        @attacher.url(foo: "foo")

        @attacher.set(original: @uploader.upload(fakeio))
        @attacher.expects(:default_url).with(version: :thumb, foo: "foo")
        @attacher.url(:thumb, foo: "foo")
        @attacher.set(nil)
        @attacher.expects(:default_url).with(version: :thumb, foo: "foo")
        @attacher.url(:thumb, foo: "foo")
      end

      it "supports :fallbacks" do
        @shrine.plugin :versions, fallbacks: { medium: :thumb, large:  :medium }

        @attacher.set(thumb: @uploader.upload(fakeio))
        assert_equal @attacher.url(:thumb), @attacher.url(:medium)
        assert_equal @attacher.url(:thumb), @attacher.url(:large)
      end

      it "supports :fallback_to_original" do
        @shrine.plugin :versions, fallback_to_original: false

        @attacher.expects(:default_url).with(version: :thumbnail, foo: "foo")
        @attacher.url(:thumbnail, foo: "foo")

        @attacher.assign(fakeio)
        @attacher.expects(:default_url).with(version: :thumbnail, foo: "foo")
        @attacher.url(:thumbnail, foo: "foo")
      end
    end
  end
end
