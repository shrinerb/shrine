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
      it "allows processing into versions" do
        result = -> (io) { }
        @shrine.process(:foo) { |io, **| result.(io) }

        result = -> (io) { { thumb: io } }
        versions = @uploader.upload(fakeio("file"), action: :foo)
        assert_equal "file", versions.fetch(:thumb).read

        result = -> (io) { [io] }
        versions = @uploader.upload(fakeio("file"), action: :foo)
        assert_equal "file", versions.fetch(0).read

        result = -> (io) { { thumb: [io] } }
        versions = @uploader.upload(fakeio("file"), action: :foo)
        assert_equal "file", versions.fetch(:thumb).fetch(0).read

        # processing into single file still works
        result = -> (io) { io }
        file = @uploader.upload(fakeio("file"))
        assert_equal "file", file.read
      end

      it "allows reprocessing versions" do
        result = -> (x) { }
        @shrine.process(:foo) { |x, **| result.(x) }

        result = -> (x) { { thumb: x.fetch(:thumb) } }
        versions = @uploader.upload({ thumb: fakeio("thumb") }, action: :foo)
        assert_equal "thumb", versions.fetch(:thumb).read

        result = -> (x) { [x.fetch(0)] }
        versions = @uploader.upload([fakeio("thumb")], action: :foo)
        assert_equal "thumb", versions.fetch(0).read

        result = -> (x) { { thumb: x.fetch(:thumb) } }
        versions = @uploader.upload({ thumb: [fakeio("thumb")] }, action: :foo)
        assert_equal "thumb", versions.fetch(:thumb).fetch(0).read
      end

      it "accepts versions" do
        versions = @uploader.upload({ thumb: fakeio })
        assert_kind_of Shrine::UploadedFile, versions.fetch(:thumb)

        versions = @uploader.upload([fakeio])
        assert_kind_of Shrine::UploadedFile, versions.fetch(0)

        versions = @uploader.upload({ thumb: [fakeio] })
        assert_kind_of Shrine::UploadedFile, versions.fetch(:thumb).fetch(0)

        # uploading a single file still works
        file = @uploader.upload(fakeio)
        assert_kind_of Shrine::UploadedFile, file
      end

      it "passes the version name to location generator" do
        @uploader.instance_eval { def generate_location(io, version:, **); version.to_s; end }
        versions = @uploader.upload({ thumb: fakeio })
        assert_equal "thumb", versions.fetch(:thumb).id

        @uploader.instance_eval { def generate_location(io, version:, **); version.to_s; end }
        versions = @uploader.upload([fakeio])
        assert_equal "0", versions.fetch(0).id

        @uploader.instance_eval { def generate_location(io, version:, **); version.to_s; end }
        versions = @uploader.upload({ thumb: [fakeio] })
        assert_equal "[:thumb, 0]", versions.fetch(:thumb).fetch(0).id

        # doesn't pass it in case of a single file
        @uploader.instance_eval { def generate_location(io, options); options.key?(:version).to_s; end }
        file = @uploader.upload(fakeio)
        assert_equal "false", file.id
      end

      it "coerces version names into symbols" do
        @shrine.process(:foo) { |io| { "name" => io } }

        versions = @uploader.upload(fakeio, action: :foo)

        assert versions.key?(:name)
        assert versions.fetch(:name).exists?
      end

      it "still supports custom #process" do
        @uploader.instance_eval { def process(io, **); { thumb: io }; end }
        versions = @uploader.upload(fakeio("file"))
        assert_equal "file", versions.fetch(:thumb).read

        @uploader.instance_eval { def process(io, **); nil; end }
        file = @uploader.upload(fakeio("file"))
        assert_equal "file", file.read
      end

      it "still catches invalid IOs" do
        @shrine.process(:foo) { |io| { thumb: "invalid IO" } }
        error = assert_raises(Shrine::InvalidFile) do
          @uploader.upload(fakeio, action: :foo)
        end
        assert_match /is not a valid IO object/, error.message
      end
    end

    describe ".uploaded_file" do
      it "loads versions from Hash data" do
        file = @uploader.upload(fakeio)

        assert_equal Hash[thumb: file],   @shrine.uploaded_file({ "thumb" => file.data })
        assert_equal [file],              @shrine.uploaded_file([file.data])
        assert_equal Hash[thumb: [file]], @shrine.uploaded_file({ thumb: [file.data] })
        assert_equal file,                @shrine.uploaded_file(file.data)
      end

      it "loads versions from JSON data" do
        file = @uploader.upload(fakeio)

        assert_equal Hash[thumb: file],   @shrine.uploaded_file({ "thumb" => file.data }.to_json)
        assert_equal [file],              @shrine.uploaded_file([file.data].to_json)
        assert_equal Hash[thumb: [file]], @shrine.uploaded_file({ thumb: [file.data] }.to_json)
        assert_equal file,                @shrine.uploaded_file(file.to_json)
      end

      it "loads versions from Hash of UploadedFiles" do
        file = @uploader.upload(fakeio)

        assert_equal Hash[thumb: file],   @shrine.uploaded_file({ "thumb" => file })
        assert_equal [file],              @shrine.uploaded_file([file])
        assert_equal Hash[thumb: [file]], @shrine.uploaded_file({ thumb: [file] })
        assert_equal file,                @shrine.uploaded_file(file)
      end

      it "yields versions if block is given" do
        file = @uploader.upload(fakeio)

        yielded = []
        assert_equal Hash[thumb: file], @shrine.uploaded_file({ "thumb" => file.data }) { |f| yielded << f }
        assert_equal [file], yielded

        yielded = []
        assert_equal [file], @shrine.uploaded_file([file]) { |f| yielded << f }
        assert_equal [file], yielded

        yielded = []
        assert_equal Hash[thumb: [file]], @shrine.uploaded_file({ thumb: [file] }) { |f| yielded << f }
        assert_equal [file], yielded

        yielded = []
        assert_equal file, @shrine.uploaded_file(file) { |f| yielded << f }
        assert_equal [file], yielded
      end
    end
  end

  describe "Attacher" do
    describe "#assign" do
      it "assigns versions" do
        versions = { thumb: @shrine.upload(fakeio, :cache) }
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
        @attacher.set({ thumb: @uploader.upload(fakeio) })
        @attacher.destroy_attached
        refute @attacher.get[:thumb].exists?

        @attacher.set([@uploader.upload(fakeio)])
        @attacher.destroy_attached
        refute @attacher.get[0].exists?

        @attacher.set({ thumb: [@uploader.upload(fakeio)] })
        @attacher.destroy_attached
        refute @attacher.get[:thumb][0].exists?

        @attacher.set(@uploader.upload(fakeio))
        @attacher.destroy_attached
        refute @attacher.file.exists?
      end
    end

    describe "#destroy_previous" do
      it "deletes versions" do
        @attacher.change(original = { thumb: @uploader.upload(fakeio) })
        @attacher.change({ thumb: @uploader.upload(fakeio) })
        @attacher.destroy_previous
        refute original[:thumb].exists?

        @attacher.change(original = [@uploader.upload(fakeio)])
        @attacher.change([@uploader.upload(fakeio)])
        @attacher.destroy_previous
        refute original[0].exists?

        @attacher.change(original = { thumb: [@uploader.upload(fakeio)] })
        @attacher.change({ thumb: [@uploader.upload(fakeio)] })
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
        @attacher.change({ thumb: @shrine.upload(fakeio, :cache) })
        @attacher.promote_cached
        assert_equal :store, @attacher.get[:thumb].storage_key

        @attacher.change([@shrine.upload(fakeio, :cache)])
        @attacher.promote_cached
        assert_equal :store, @attacher.get[0].storage_key

        @attacher.change({ thumb: [@shrine.upload(fakeio, :cache)] })
        @attacher.promote_cached
        assert_equal :store, @attacher.get[:thumb][0].storage_key

        @attacher.change(@shrine.upload(fakeio, :cache))
        @attacher.promote_cached
        assert_equal :store, @attacher.file.storage_key
      end
    end

    describe "#url" do
      it "accepts a version name indifferently" do
        @attacher.set({ thumb: @uploader.upload(fakeio) })
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
        @attacher.set({ thumb: @uploader.upload(fakeio) })
        assert_raises(Shrine::Error) { @attacher.url }
      end

      it "passes in :version to the default url" do
        @attacher.class.default_url { |options| "missing #{options[:version]}" }
        assert_equal "missing thumb", @attacher.url(:thumb)
      end

      it "forwards url options" do
        @attacher.set({ thumb: @uploader.upload(fakeio) })
        Shrine::UploadedFile.any_instance.expects(:url).with(foo: "foo")
        @attacher.url(:thumb, foo: "foo")
        @attacher.set(@uploader.upload(fakeio))
        Shrine::UploadedFile.any_instance.expects(:url).with(foo: "foo")
        @attacher.url(:thumb, foo: "foo")
        Shrine::UploadedFile.any_instance.expects(:url).with(foo: "foo")
        @attacher.url(foo: "foo")

        @attacher.set({ original: @uploader.upload(fakeio) })
        @attacher.expects(:default_url).with(version: :thumb, foo: "foo")
        @attacher.url(:thumb, foo: "foo")
        @attacher.set(nil)
        @attacher.expects(:default_url).with(version: :thumb, foo: "foo")
        @attacher.url(:thumb, foo: "foo")
      end

      it "supports :fallbacks" do
        @shrine.plugin :versions, fallbacks: { medium: :thumb, large:  :medium }

        @attacher.set({ thumb: @uploader.upload(fakeio) })
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

    describe "#data" do
      it "converts versions into a Hash of data" do
        file = @uploader.upload(fakeio)

        @attacher.set({ thumb: file })
        assert_equal Hash["thumb" => file.data], @attacher.data

        @attacher.set([file])
        assert_equal [file.data], @attacher.data

        @attacher.set({ thumb: [file] })
        assert_equal Hash["thumb" => [file.data]], @attacher.data

        @attacher.set(file)
        assert_equal file.data, @attacher.data
      end
    end

    describe "#load_data" do
      it "loads versions data" do
        file = @uploader.upload(fakeio)

        @attacher.load_data({ "thumb" => file.data })
        assert_equal Hash[thumb: file], @attacher.file

        @attacher.load_data([file.data])
        assert_equal [file], @attacher.file

        @attacher.load_data({ thumb: [file.data] })
        assert_equal Hash[thumb: [file]], @attacher.file

        @attacher.load_data(file.data)
        assert_equal file, @attacher.file
      end
    end

    describe "#file=" do
      it "accepts a Hash of versions" do
        file = @uploader.upload(fakeio)

        @attacher.file = { thumb: file }
        assert_equal Hash[thumb: file], @attacher.file
      end

      it "accepts an Array of versions" do
        file = @uploader.upload(fakeio)

        @attacher.file = [file]
        assert_equal [file], @attacher.file
      end
    end

    describe "#uploaded_file" do
      it "passes a block to Shrine.uploaded_file" do
        file = @uploader.upload(fakeio)

        yielded = []
        @attacher.uploaded_file(file) { |f| yielded << f }

        assert_equal [file], yielded
      end
    end

    describe "#cached?" do
      it "returns true if versions are cached" do
        assert_equal true, @attacher.cached?({ thumb: @shrine.upload(fakeio, :cache) })
        assert_equal true, @attacher.cached?({ thumb: [@shrine.upload(fakeio, :cache)] })
        assert_equal true, @attacher.cached?([@shrine.upload(fakeio, :cache)])
        assert_equal true, @attacher.cached?(@shrine.upload(fakeio, :cache))

        assert_equal false, @attacher.cached?({ thumb: @shrine.upload(fakeio, :store) })
      end
    end

    describe "#stored?" do
      it "returns true if versions are stored" do
        assert_equal true, @attacher.stored?({ thumb: @shrine.upload(fakeio, :store) })
        assert_equal true, @attacher.stored?({ thumb: [@shrine.upload(fakeio, :store)] })
        assert_equal true, @attacher.stored?([@shrine.upload(fakeio, :store)])
        assert_equal true, @attacher.stored?(@shrine.upload(fakeio, :store))

        assert_equal false, @attacher.stored?({ thumb: @shrine.upload(fakeio, :cache) })
      end
    end
  end

  it "works with backgrounding" do
    @shrine.plugin :backgrounding
    @shrine.process(:store) do |io, **options|
      { original: io }
    end

    @attacher.promote_block { promote }
    @attacher.attach_cached(fakeio)
    @attacher.promote

    assert_instance_of Hash, @attacher.file
    assert_instance_of @shrine::UploadedFile, @attacher.file.fetch(:original)
  end
end
