require "test_helper"
require "shrine/plugins/derivatives"
require "dry-monitor"

describe Shrine::Plugins::Derivatives do
  before do
    @attacher = attacher { plugin :derivatives }
    @shrine   = @attacher.shrine_class
  end

  describe "Attachment" do
    before do
      @shrine.plugin :entity

      @attacher = @shrine::Attacher.new

      @entity_class = entity_class(:file_data)
      @entity_class.include @shrine::Attachment.new(:file)
    end

    describe "#<name>_derivatives" do
      it "returns the hash of derivatives" do
        @attacher.add_derivatives(one: fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.derivatives, entity.file_derivatives
      end

      it "forward arguments" do
        @attacher.add_derivatives(one: fakeio, two: { three: fakeio })

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.derivatives[:one],         entity.file_derivatives(:one)
        assert_equal @attacher.derivatives[:two][:three], entity.file_derivatives(:two, :three)
      end

      it "returns empty hash for no derivatives" do
        entity = @entity_class.new(file_data: nil)

        assert_equal Hash.new, entity.file_derivatives
      end
    end

    describe "#<name>" do
      it "returns derivatives with arguments" do
        @attacher.add_derivatives(one: fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.derivatives[:one], entity.file(:one)
      end

      it "still returns original file without arguments" do
        @attacher.attach(fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.file, entity.file
      end

      it "raises exception when #[] is used with symbol key" do
        @attacher.attach(fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_raises(Shrine::Error) { entity.file[:one] }
      end

      it "still allows calling #[] with string keys" do
        @attacher.attach(fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.file.size, entity.file["size"]
      end
    end

    describe "#<name>_url" do
      it "returns derivative URL with arguments" do
        @attacher.add_derivatives(one: fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.derivatives[:one].url, entity.file_url(:one)
        assert_equal @attacher.derivatives[:one].url, entity.file_url(:one, foo: "bar")
      end

      it "still returns original file URL without arguments" do
        @attacher.attach(fakeio)

        entity = @entity_class.new(file_data: @attacher.column_value)

        assert_equal @attacher.file.url, entity.file_url
        assert_equal @attacher.file.url, entity.file_url(foo: "bar")
      end
    end
  end

  describe "Attacher" do
    describe "#initialize" do
      it "initializes derivatives to empty hash" do
        attacher = @shrine::Attacher.new

        assert_equal Hash.new, attacher.derivatives
      end

      it "accepts derivatives" do
        derivatives = { one: @attacher.upload(fakeio) }
        attacher    = @shrine::Attacher.new(derivatives: derivatives)

        assert_equal derivatives, attacher.derivatives
      end

      it "forwards additional options to super" do
        attacher = @shrine::Attacher.new(store: :other_store)

        assert_equal :other_store, attacher.store_key
      end
    end

    describe "#get" do
      it "returns original file without arguments" do
        @attacher.attach(fakeio)

        assert_equal @attacher.file, @attacher.get
      end

      it "retrieves selected derivative" do
        @attacher.add_derivatives(one: fakeio)

        assert_equal @attacher.derivatives[:one], @attacher.get(:one)
      end

      it "retrieves selected nested derivative" do
        @attacher.add_derivatives(one: { two: fakeio })

        assert_equal @attacher.derivatives[:one][:two], @attacher.get(:one, :two)
      end
    end

    describe "#get_derivatives" do
      it "returns all derivatives without arguments" do
        @attacher.add_derivatives(one: fakeio)

        assert_equal @attacher.derivatives, @attacher.get_derivatives
      end

      it "retrieves derivative with given name" do
        @attacher.add_derivatives(one: fakeio)

        assert_equal @attacher.derivatives[:one], @attacher.get_derivatives(:one)
      end

      it "retrieves nested derivatives" do
        @attacher.add_derivatives(one: { two: fakeio })

        assert_equal @attacher.derivatives[:one][:two], @attacher.get_derivatives(:one, :two)
      end

      it "handles string keys" do
        @attacher.add_derivatives(one: { two: fakeio })

        assert_equal @attacher.derivatives[:one][:two], @attacher.get_derivatives("one", "two")
      end

      it "handles array indices" do
        @attacher.add_derivatives(one: [fakeio])

        assert_equal @attacher.derivatives[:one][0], @attacher.get_derivatives(:one, 0)
      end
    end

    describe "#url" do
      describe "without arguments" do
        it "returns original file URL" do
          @attacher.attach(fakeio)

          assert_equal @attacher.file.url, @attacher.url
        end

        it "returns nil when original file is missing" do
          assert_nil @attacher.url
        end

        it "returns default URL when original file is missing" do
          @shrine::Attacher.default_url { "default_url" }

          assert_equal "default_url", @attacher.url
        end

        it "passes options to the default URL block" do
          @shrine::Attacher.default_url { |options| options[:foo] }

          assert_equal "bar", @attacher.url(foo: "bar")
        end
      end

      describe "with arguments" do
        it "returns derivative URL" do
          @attacher.add_derivatives(one: fakeio)

          assert_equal @attacher.derivatives[:one].url, @attacher.url(:one)
        end

        it "returns nested derivative URL" do
          @attacher.add_derivatives(one: { two: fakeio })

          assert_equal @attacher.derivatives[:one][:two].url, @attacher.url(:one, :two)
        end

        it "passes URL options to derivative URL" do
          @attacher.add_derivatives(one: fakeio)

          @attacher.derivatives[:one].expects(:url).with(foo: "bar")

          @attacher.url(:one, foo: "bar")
        end

        it "returns nil when derivative is not present" do
          assert_nil @attacher.url(:one)
        end

        it "handles string keys" do
          @attacher.add_derivatives(one: fakeio)

          assert_equal @attacher.derivatives[:one].url, @attacher.url(:one)
        end

        it "works with default URL" do
          @shrine::Attacher.default_url { "default_url" }

          @attacher.add_derivatives(one: fakeio)

          assert_equal @attacher.derivatives[:one].url, @attacher.url(:one)
          assert_equal "default_url",                   @attacher.url(:two)
        end

        it "passes :derivative to default URL block" do
          @shrine::Attacher.default_url { |options| options[:derivative].inspect }

          assert_equal ":one",         @attacher.url(:one)
          assert_equal "[:one, :two]", @attacher.url(:one, :two)
        end

        it "passes options to the default URL block" do
          @shrine::Attacher.default_url { |options| options[:foo] }

          assert_equal "bar", @attacher.url(:one, foo: "bar")
        end
      end
    end

    describe "#promote" do
      it "uploads cached derivatives to permanent storage" do
        @attacher.attach_cached(fakeio)
        @attacher.add_derivative(:one, fakeio, storage: :cache)

        @attacher.promote

        assert_equal :store, @attacher.file.storage_key
        assert_equal :store, @attacher.derivatives[:one].storage_key
      end

      it "forwards promote options" do
        @attacher.attach_cached(fakeio)

        @attacher.promote(location: "foo")

        assert_equal "foo", @attacher.file.id
      end

      it "works with backgrounding plugin" do
        @attacher = attacher do
          plugin :backgrounding
          plugin :derivatives
        end

        @attacher.promote_block do |attacher|
          @job = Fiber.new { @attacher.promote }
        end

        @attacher.attach_cached(fakeio)
        @attacher.add_derivative(:one, fakeio, storage: :cache)

        @attacher.promote(background: true)

        assert_equal :cache, @attacher.file.storage_key
        assert_equal :cache, @attacher.derivatives[:one].storage_key

        @job.resume

        assert_equal :store, @attacher.file.storage_key
        assert_equal :store, @attacher.derivatives[:one].storage_key
      end
    end

    describe "#promote_derivatives" do
      it "uploads cached derivatives to permanent storage" do
        @attacher.add_derivative(:one,   fakeio("one"),   storage: :cache)
        @attacher.add_derivative(:two,   fakeio("two"),   storage: :store)
        @attacher.add_derivative(:three, fakeio("three"), storage: :other_store)

        derivatives = @attacher.derivatives

        @attacher.promote_derivatives

        assert_equal :store,       @attacher.derivatives[:one].storage_key
        assert_equal :store,       @attacher.derivatives[:two].storage_key
        assert_equal :other_store, @attacher.derivatives[:three].storage_key

        assert_equal "one",   @attacher.derivatives[:one].read
        assert_equal "two",   @attacher.derivatives[:two].read
        assert_equal "three", @attacher.derivatives[:three].read

        refute_equal derivatives[:one],   @attacher.derivatives[:one]
        assert_equal derivatives[:two],   @attacher.derivatives[:two]
        assert_equal derivatives[:three], @attacher.derivatives[:three]
      end

      it "handles nested derivatives" do
        @attacher.add_derivatives({ one: { two: fakeio } }, storage: :cache)
        @attacher.promote_derivatives

        assert_equal :store, @attacher.derivatives[:one][:two].storage_key
      end

      it "forwards promote options" do
        @attacher.add_derivative(:one, fakeio, storage: :cache)

        @attacher.promote_derivatives(location: "foo")

        assert_equal "foo", @attacher.derivatives[:one].id
      end

      it "doesn't clear original file" do
        @attacher.attach_cached(fakeio)
        @attacher.add_derivative(:one, fakeio, storage: :cache)

        @attacher.promote_derivatives

        assert_equal :cache, @attacher.file.storage_key
      end
    end

    describe "#destroy" do
      it "deletes derivatives" do
        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: fakeio)

        @attacher.destroy

        refute @attacher.file.exists?
        refute @attacher.derivatives[:one].exists?
      end

      it "works with backgrounding plugin" do
        @attacher = attacher do
          plugin :backgrounding
          plugin :derivatives
        end

        @attacher.destroy_block do |attacher|
          @job = Fiber.new { @attacher.destroy }
        end

        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: fakeio)

        @attacher.destroy(background: true)

        assert @attacher.file.exists?
        assert @attacher.derivatives[:one].exists?

        @job.resume

        refute @attacher.file.exists?
        refute @attacher.derivatives[:one].exists?
      end
    end

    describe "#delete_derivatives" do
      it "deletes set derivatives" do
        @attacher.add_derivatives(one: fakeio)

        @attacher.delete_derivatives

        refute @attacher.derivatives[:one].exists?
      end

      it "deletes given derivatives" do
        derivatives = { one: @attacher.upload(fakeio) }

        @attacher.delete_derivatives(derivatives)

        refute derivatives[:one].exists?
      end

      it "handles nested derivatives" do
        derivatives = { one: { two: @attacher.upload(fakeio) } }

        @attacher.delete_derivatives(derivatives)

        refute derivatives[:one][:two].exists?
      end
    end

    describe "#add_derivatives" do
      it "uploads given files to permanent storage" do
        @attacher.add_derivatives(one: fakeio)

        assert_equal :store, @attacher.derivatives[:one].storage_key
      end

      it "accepts processor name" do
        @attacher.class.derivatives_processor :reversed do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        @attacher.add_derivatives(:reversed)

        assert_kind_of Shrine::UploadedFile, @attacher.derivatives[:reversed]
        assert_equal "elif", @attacher.derivatives[:reversed].read
      end

      it "returns added derivatives" do
        derivatives = @attacher.add_derivatives(one: fakeio("one"))

        assert_instance_of @shrine::UploadedFile, derivatives[:one]
        assert_equal "one", derivatives[:one].read
      end

      it "merges files with existing derivatives" do
        @attacher.add_derivatives(one: fakeio)
        @attacher.add_derivatives(two: fakeio)

        assert_equal %i[one two], @attacher.derivatives.keys
        assert_kind_of Shrine::UploadedFile, @attacher.derivatives[:two]
      end

      it "accepts additional options" do
        @attacher.add_derivatives({ one: fakeio }, storage: :other_store)

        assert_equal :other_store, @attacher.derivatives[:one].storage_key
      end

      it "handles nested derivatives" do
        @attacher.add_derivatives(one: { two: fakeio })

        assert_kind_of Shrine::UploadedFile, @attacher.derivatives[:one][:two]
      end

      it "handles string keys" do
        derivatives = @attacher.add_derivatives("one" => fakeio)

        assert_kind_of Shrine::UploadedFile, @attacher.derivatives[:one]
        assert_kind_of Shrine::UploadedFile, derivatives[:one]
      end
    end

    describe "#add_derivative" do
      it "uploads given file to permanent storage" do
        @attacher.add_derivative(:one, fakeio)

        assert_equal :store, @attacher.derivatives[:one].storage_key
      end

      it "returns added derivative" do
        derivative = @attacher.add_derivative(:one, fakeio("one"))

        assert_instance_of @shrine::UploadedFile, derivative
        assert_equal "one", derivative.read
      end

      it "accepts additional options" do
        @attacher.add_derivative(:one, fakeio, storage: :other_store)

        assert_equal :other_store, @attacher.derivatives[:one].storage_key
      end

      it "handles string keys" do
        @attacher.add_derivative("one", fakeio)

        assert_kind_of Shrine::UploadedFile, @attacher.derivatives[:one]
      end

      it "merges with existing derivatives" do
        @attacher.add_derivative(:one, fakeio)
        @attacher.add_derivative(:two, fakeio)

        assert_equal %i[one two], @attacher.derivatives.keys
        assert_kind_of Shrine::UploadedFile, @attacher.derivatives[:two]
      end
    end

    describe "#upload_derivatives" do
      it "uploads given files to permanent storage" do
        derivatives = @attacher.upload_derivatives(one: fakeio)

        assert_kind_of Shrine::UploadedFile, derivatives[:one]
        assert_equal :store, derivatives[:one].storage_key
        assert derivatives[:one].exists?
      end

      it "accepts processor name" do
        @attacher.class.derivatives_processor :reversed do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        derivatives = @attacher.upload_derivatives(:reversed)

        assert_kind_of Shrine::UploadedFile, derivatives[:reversed]
        assert_equal "elif", derivatives[:reversed].read
      end

      it "passes derivative name for uploading" do
        io = fakeio
        @shrine.any_instance.expects(:extract_metadata).with(io, derivative: :one).returns({})
        @attacher.upload_derivatives(one: io)

        io = fakeio
        @shrine.any_instance.expects(:extract_metadata).with(io, derivative: [:one, :two]).returns({})
        @attacher.upload_derivatives(one: { two: io })
      end

      it "accepts additional options" do
        derivatives = @attacher.upload_derivatives({ one: fakeio }, storage: :other_store)

        assert_equal :other_store, derivatives[:one].storage_key

        assert derivatives[:one].exists?
      end

      it "handles nested derivatives" do
        derivatives = @attacher.upload_derivatives(one: { two: fakeio })

        assert_kind_of Shrine::UploadedFile, derivatives[:one][:two]
        assert_equal :store, derivatives[:one][:two].storage_key
        assert derivatives[:one][:two].exists?
      end

      it "handles string keys" do
        io = fakeio
        @shrine.any_instance.expects(:extract_metadata).with(io, derivative: :one).returns({})
        derivatives = @attacher.upload_derivatives("one" => io)
        assert_kind_of Shrine::UploadedFile, derivatives[:one]

        io = fakeio
        @shrine.any_instance.expects(:extract_metadata).with(io, derivative: [:one, :two]).returns({})
        derivatives = @attacher.upload_derivatives("one" => { "two" => io })
        assert_kind_of Shrine::UploadedFile, derivatives[:one][:two]
      end
    end

    describe "#upload_derivative" do
      it "uploads given IO to permanent storage" do
        derivative = @attacher.upload_derivative(:one, fakeio("one"))

        assert_instance_of @shrine::UploadedFile, derivative
        assert_equal :store, derivative.storage_key
        assert derivative.exists?
        assert_equal "one", derivative.read
      end

      it "uses :storage plugin option" do
        @shrine.plugin :derivatives, storage: :other_store
        derivative = @attacher.upload_derivative(:one, fakeio)
        assert_equal :other_store, derivative.storage_key

        minitest = self
        @shrine.plugin :derivatives, storage: -> (name) {
          minitest.assert_equal :one, name
          minitest.assert_kind_of Shrine::Attacher, self
          :other_store
        }
        derivative = @attacher.upload_derivative(:one, fakeio)
        assert_equal :other_store, derivative.storage_key
      end

      it "uses Attacher.derivative_storage value" do
        @attacher.class.derivatives_storage :other_store
        derivative = @attacher.upload_derivative(:one, fakeio)
        assert_equal :other_store, derivative.storage_key

        minitest = self
        @attacher.class.derivatives_storage do |name|
          minitest.assert_equal :one, name
          minitest.assert_kind_of Shrine::Attacher, self
          :other_store
        end
        derivative = @attacher.upload_derivative(:one, fakeio)
        assert_equal :other_store, derivative.storage_key
      end

      it "allows selecting storage" do
        derivative = @attacher.upload_derivative(:one, fakeio, storage: :other_store)

        assert_equal :other_store, derivative.storage_key
      end

      it "forwards derivative name for uploading" do
        io = fakeio
        @shrine.any_instance.expects(:extract_metadata).with(io, derivative: :one).returns({})
        @attacher.upload_derivative(:one, io)

        io = fakeio
        @shrine.any_instance.expects(:extract_metadata).with(io, derivative: [:one, :two]).returns({})
        @attacher.upload_derivative([:one, :two], io)
      end

      it "forwards additional options for uploading" do
        derivative = @attacher.upload_derivative(:one, fakeio, location: "foo")

        assert_equal "foo", derivative.id
      end

      it "deletes uploaded files" do
        file = tempfile("file")
        @attacher.upload_derivative(:one, File.open(file.path))

        refute File.exist?(file.path)
      end

      it "handles file being moved on upload" do
        @shrine.storages[:store].instance_eval do
          def upload(io, id, **options)
            super
            File.delete(io.path)
          end
        end
        file = tempfile("file")
        @attacher.upload_derivative(:one, File.open(file.path))

        refute File.exist?(file.path)
      end

      it "skips deletion when :delete is false" do
        file = tempfile("file")
        @attacher.upload_derivative(:one, File.open(file.path), delete: false)

        assert File.exist?(file.path)
      end
    end

    describe "#process_derivatives" do
      it "calls the registered processor" do
        @attacher.class.derivatives_processor :reversed do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        files = @attacher.process_derivatives(:reversed)

        assert_instance_of StringIO, files[:reversed]
        assert_equal "elif", files[:reversed].read
      end

      it "passes downloaded attached file" do
        minitest = self
        @attacher.class.derivatives_processor :reversed do |original|
          minitest.assert_instance_of Tempfile, original

          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        @attacher.process_derivatives(:reversed)
      end

      it "allows passing source file" do
        @attacher.class.derivatives_processor :reversed do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        @attacher.file.expects(:download).never

        files = @attacher.process_derivatives(:reversed, fakeio("other"))

        assert_instance_of StringIO, files[:reversed]
        assert_equal "rehto", files[:reversed].read
      end

      it "forwards additional options" do
        @attacher.class.derivatives_processor :options do |original, **options|
          { options: StringIO.new(options.to_s) }
        end

        @attacher.attach(fakeio)
        files = @attacher.process_derivatives(:options, foo: "bar")

        assert_equal '{:foo=>"bar"}', files[:options].read
      end

      it "evaluates block in context of Attacher instance" do
        this = nil
        @attacher.class.derivatives_processor :reversed do |original|
          this = self
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach(fakeio)
        @attacher.process_derivatives(:reversed)

        assert_equal @attacher, this
      end

      it "handles string keys" do
        @attacher.class.derivatives_processor :symbol_reversed do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        @attacher.process_derivatives("symbol_reversed")

        @attacher.class.derivatives_processor "string_reversed" do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        @attacher.attach fakeio("file")
        @attacher.process_derivatives(:string_reversed)
      end

      it "fails if process result is not a Hash" do
        @attacher.class.derivatives_processor :reversed do |original|
          :invalid
        end

        @attacher.attach(fakeio)

        assert_raises Shrine::Error do
          @attacher.process_derivatives(:reversed)
        end
      end

      it "fails if processor was not found" do
        @attacher.attach(fakeio)

        assert_raises Shrine::Error do
          @attacher.process_derivatives(:unknown)
        end
      end

      it "fails if no file is attached" do
        @attacher.class.derivatives_processor :reversed do |original|
          { reversed: StringIO.new(original.read.reverse) }
        end

        assert_raises Shrine::Error do
          @attacher.process_derivatives(:reversed)
        end
      end

      describe "with instrumentation" do
        before do
          @shrine.plugin :instrumentation, notifications: Dry::Monitor::Notifications.new(:test)

          @attacher.class.derivatives_processor :reversed do |original|
            { reversed: StringIO.new(original.read.reverse) }
          end

          @attacher.attach(fakeio)
        end

        it "logs derivatives processing" do
          @shrine.plugin :derivatives

          assert_logged /^Derivatives \(\d+ms\) – \{.+\}$/ do
            @attacher.process_derivatives(:reversed)
          end
        end

        it "sends derivatives processing event" do
          @shrine.plugin :derivatives

          @shrine.subscribe(:derivatives) { |event| @event = event }
          @attacher.process_derivatives(:reversed, foo: "bar")

          refute_nil @event
          assert_equal :derivatives,     @event.name
          assert_equal :reversed,        @event[:processor]
          assert_equal Hash[foo: "bar"], @event[:processor_options]
          assert_equal @shrine,          @event[:uploader]
          assert_kind_of Integer,        @event.duration
        end

        it "allows swapping log subscriber" do
          @shrine.plugin :derivatives, log_subscriber: -> (event) { @event = event }

          refute_logged /^Derivatives/ do
            @attacher.process_derivatives(:reversed)
          end

          refute_nil @event
        end

        it "allows disabling log subscriber" do
          @shrine.plugin :derivatives, log_subscriber: nil

          refute_logged /^Derivatives/ do
            @attacher.process_derivatives(:reversed)
          end
        end
      end
    end

    describe "#remove_derivatives" do
      it "removes top level derivatives" do
        @attacher.add_derivatives(one: fakeio, two: fakeio)

        one = @attacher.derivatives[:one]
        two = @attacher.derivatives[:two]

        derivative = @attacher.remove_derivatives(:one)

        assert_equal Hash[two: two], @attacher.derivatives
        assert_equal one, derivative
        assert derivative.exists?
      end

      it "removes nested derivatives" do
        @attacher.add_derivatives(one: { two: fakeio }, three: fakeio)

        two   = @attacher.derivatives[:one][:two]
        three = @attacher.derivatives[:three]

        derivative = @attacher.remove_derivatives(:one, :two)

        assert_equal Hash[one: {}, three: three], @attacher.derivatives
        assert_equal two, derivative
        assert derivative.exists?
      end

      it "is aliased to #remove_derivative" do
        @attacher.add_derivatives(one: fakeio, two: fakeio)

        one = @attacher.derivatives[:one]
        two = @attacher.derivatives[:two]

        derivative = @attacher.remove_derivative(:one)

        assert_equal Hash[two: two], @attacher.derivatives
        assert_equal one, derivative
        assert derivative.exists?
      end
    end

    describe "#set_derivatives" do
      it "sets block result as derivatives" do
        derivatives = @attacher.upload_derivatives(one: fakeio)
        @attacher.set_derivatives { derivatives }

        assert_equal derivatives, @attacher.derivatives
      end

      it "returns set derivatives" do
        derivatives = @attacher.upload_derivatives(one: fakeio)

        assert_equal derivatives, @attacher.set_derivatives { derivatives }
      end

      it "yields current derivatives" do
        @attacher.derivatives = @attacher.upload_derivatives(one: fakeio)

        @attacher.set_derivatives do |derivatives|
          assert_equal @attacher.derivatives, derivatives
          @attacher.derivatives
        end
      end

      it "doesn't clear the attached file" do
        @attacher.attach(fakeio)
        @attacher.set_derivatives { @attacher.upload_derivatives(one: fakeio) }

        assert_kind_of Shrine::UploadedFile, @attacher.file
      end

      it "triggers model writing" do
        @shrine.plugin :model

        model = model(file_data: nil)
        @attacher.load_model(model, :file)

        @attacher.attach(fakeio)
        assert_equal @attacher.column_value, model.file_data

        @attacher.add_derivatives(one: fakeio)
        assert_equal @attacher.column_value, model.file_data
      end
    end

    describe "#data" do
      it "adds derivatives data to existing hash" do
        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: fakeio)

        assert_equal @attacher.file.data.merge(
          "derivatives" => {
            "one" => @attacher.derivatives[:one].data
          }
        ), @attacher.data
      end

      it "handles nested derivatives" do
        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: { two: fakeio })

        assert_equal @attacher.file.data.merge(
          "derivatives" => {
            "one" => { "two" => @attacher.derivatives[:one][:two].data }
          }
        ), @attacher.data
      end

      it "allows no attached file" do
        @attacher.add_derivatives(one: fakeio)

        assert_equal Hash[
          "derivatives" => {
            "one" => @attacher.derivatives[:one].data
          }
        ], @attacher.data
      end

      it "returns attached file data without derivatives" do
        @attacher.attach(fakeio)

        assert_equal @attacher.file.data, @attacher.data
      end

      it "returns nil without attached file or derivatives" do
        assert_nil @attacher.data
      end
    end

    describe "#load_data" do
      it "loads derivatives" do
        file        = @attacher.upload(fakeio)
        derivatives = @attacher.upload_derivatives(one: fakeio)

        @attacher.load_data file.data.merge(
          "derivatives" => {
            "one" => derivatives[:one].data,
          }
        )

        assert_equal file,        @attacher.file
        assert_equal derivatives, @attacher.derivatives
      end

      it "handles nested derivatives" do
        file        = @attacher.upload(fakeio)
        derivatives = @attacher.upload_derivatives(one: { two: fakeio })

        @attacher.load_data file.data.merge(
          "derivatives" => {
            "one" => { "two" => derivatives[:one][:two].data }
          }
        )

        assert_equal file,        @attacher.file
        assert_equal derivatives, @attacher.derivatives
      end

      it "loads derivatives without attached file" do
        derivatives = @attacher.upload_derivatives(one: fakeio)

        @attacher.load_data(
          "derivatives" => {
            "one" => derivatives[:one].data,
          }
        )

        assert_equal derivatives, @attacher.derivatives
        assert_nil @attacher.file
      end

      it "handles symbol keys" do
        file        = @attacher.upload(fakeio)
        derivatives = @attacher.upload_derivatives(one: fakeio)

        @attacher.load_data file.data.merge(
          derivatives: {
            one: derivatives[:one].data,
          }
        )

        assert_equal file,        @attacher.file
        assert_equal derivatives, @attacher.derivatives
      end

      it "clears derivatives when there is no derivatives data" do
        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: fakeio)

        @attacher.load_data @attacher.file.data

        assert_equal Hash.new, @attacher.derivatives
      end

      it "works with frozen data hash" do
        file        = @attacher.upload(fakeio)
        derivatives = @attacher.upload_derivatives(one: fakeio)

        @attacher.load_data file.data.merge(
          "derivatives" => {
            "one" => derivatives[:one].data,
          }
        ).freeze
      end

      it "loads attached file data" do
        file = @attacher.upload(fakeio)

        @attacher.load_data(file.data)

        assert_equal file, @attacher.file
      end

      it "loads no attached file or derivatives" do
        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: fakeio)

        @attacher.load_data(nil)

        assert_nil @attacher.file
        assert_equal Hash.new, @attacher.derivatives
      end
    end

    describe "#change" do
      it "clears derivatives" do
        @attacher.attach(fakeio)
        @attacher.add_derivatives(one: fakeio)

        file = @attacher.upload(fakeio)
        @attacher.change(file)

        assert_equal Hash.new, @attacher.derivatives
        assert_equal file,     @attacher.file
      end

      it "records previous derivatives" do
        file        = @attacher.attach(fakeio)
        derivatives = @attacher.add_derivatives(one: fakeio)

        @attacher.change(nil)
        @attacher.destroy_previous

        refute file.exists?
        refute derivatives[:one].exists?
      end
    end

    describe "#derivatives=" do
      it "sets given derivatives" do
        derivatives = { one: @attacher.upload(fakeio) }
        @attacher.derivatives = derivatives

        assert_equal derivatives, @attacher.derivatives
      end

      it "raises exception if given object is not a Hash" do
        assert_raises ArgumentError do
          @attacher.derivatives = [@attacher.upload(fakeio)]
        end
      end
    end

    describe "versions compatibility" do
      before do
        @shrine.plugin :derivatives, versions_compatibility: true
      end

      describe "#load_data" do
        it "loads versions data with original (string)" do
          file    = @attacher.upload(fakeio)
          version = @attacher.upload(fakeio)

          @attacher.load_data("original" => file.data, "version" => version.data)

          assert_equal file,                   @attacher.file
          assert_equal Hash[version: version], @attacher.derivatives
        end

        it "loads versions data with original (symbol)" do
          file    = @attacher.upload(fakeio)
          version = @attacher.upload(fakeio)

          @attacher.load_data(original: file.data, version: version.data)

          assert_equal file,                   @attacher.file
          assert_equal Hash[version: version], @attacher.derivatives
        end

        it "loads versions data without original (string)" do
          version = @attacher.upload(fakeio)

          @attacher.load_data("version" => version.data)

          assert_equal Hash[version: version], @attacher.derivatives
          assert_nil @attacher.file
        end

        it "loads versions data without original (symbol)" do
          version = @attacher.upload(fakeio)

          @attacher.load_data(version: version.data)

          assert_equal Hash[version: version], @attacher.derivatives
          assert_nil @attacher.file
        end

        it "still works with native data format (string)" do
          file    = @attacher.upload(fakeio)
          version = @attacher.upload(fakeio)

          @attacher.load_data file.data.merge(
            "derivatives" => {
              "version" => version.data
            }
          )

          assert_equal file,                   @attacher.file
          assert_equal Hash[version: version], @attacher.derivatives
        end

        it "still works with native data format (symbol)" do
          file    = @attacher.upload(fakeio)
          version = @attacher.upload(fakeio)

          @attacher.load_data file.data.merge(
            derivatives: {
              version: version.data
            }
          )

          assert_equal file,                   @attacher.file
          assert_equal Hash[version: version], @attacher.derivatives
        end

        it "still works with plain file data (string)" do
          file = @attacher.upload(fakeio)

          @attacher.load_data(file.data)

          assert_equal file,     @attacher.file
          assert_equal Hash.new, @attacher.derivatives
        end

        it "still works with plain file data (symbol)" do
          file = @attacher.upload(fakeio)

          @attacher.load_data(
            id:       file.id,
            storage:  file.storage_key,
            metadata: file.metadata,
          )

          assert_equal file,     @attacher.file
          assert_equal Hash.new, @attacher.derivatives
        end

        it "still works with nil data" do
          @attacher.attach(fakeio)
          @attacher.add_derivatives(one: fakeio)

          @attacher.load_data(nil)

          assert_nil @attacher.file
          assert_equal Hash.new, @attacher.derivatives
        end
      end
    end
  end

  describe "Shrine" do
    describe ".derivatives" do
      it "loads derivatives from Hash" do
        file = @attacher.upload(fakeio)

        derivatives = @shrine.derivatives("one" => file.data)

        assert_equal Hash[one: file], derivatives
      end

      it "loads derivatives from JSON" do
        file = @attacher.upload(fakeio)

        derivatives = @shrine.derivatives({ "one" => file.data }.to_json)

        assert_equal Hash[one: file], derivatives
      end

      it "loads nested derivatives" do
        file = @attacher.upload(fakeio)

        derivatives = @shrine.derivatives("one" => { "two" => [file.data] })

        assert_equal Hash[one: { two: [file] }], derivatives
      end

      it "handles top-level arrays" do
        file = @attacher.upload(fakeio)

        derivatives = @shrine.derivatives([file.data])

        assert_equal [file], derivatives
      end

      it "handles symbol keys" do
        file = @attacher.upload(fakeio)

        derivatives = @shrine.derivatives(one: {
          id:       file.id,
          storage:  file.storage_key,
          metadata: file.metadata,
        })

        assert_equal Hash[one: file], derivatives
      end

      it "allows UploadedFile values" do
        file = @attacher.upload(fakeio)

        derivatives = @shrine.derivatives(one: file)

        assert_equal Hash[one: file], derivatives
      end

      it "raises exception on invalid input" do
        assert_raises(ArgumentError) { @shrine.derivatives(:invalid) }
      end
    end

    describe ".map_derivative" do
      it "iterates over simple hash" do
        derivatives = { one: fakeio }

        @shrine.map_derivative(derivatives) do |path, file|
          assert_equal [:one],            path
          assert_equal derivatives[:one], file
        end
      end

      it "iterates over simple array" do
        derivatives = [fakeio]

        @shrine.map_derivative(derivatives) do |path, file|
          assert_equal [0],            path
          assert_equal derivatives[0], file
        end
      end

      it "iterates over nested hash" do
        derivatives = { one: { two: fakeio } }

        @shrine.map_derivative(derivatives) do |path, file|
          assert_equal [:one, :two],            path
          assert_equal derivatives[:one][:two], file
        end
      end

      it "iterates over nested array" do
        derivatives = { one: [fakeio] }

        @shrine.map_derivative(derivatives) do |path, file|
          assert_equal [:one, 0],            path
          assert_equal derivatives[:one][0], file
        end
      end

      it "symbolizes hash keys" do
        derivatives = { "one" => { "two" => fakeio } }

        @shrine.map_derivative(derivatives) do |path, file|
          assert_equal [:one, :two],              path
          assert_equal derivatives["one"]["two"], file
        end
      end

      it "returns mapped collection" do
        derivatives = { "one" => [fakeio] }

        result = @shrine.map_derivative(derivatives) do |path, derivative|
          :mapped_value
        end

        assert_equal Hash[one: [:mapped_value]], result
      end

      it "returns enumerator when block is not passed" do
        derivatives = { one: fakeio }

        enumerator = @shrine.map_derivative(derivatives)

        assert_instance_of Enumerator, enumerator

        assert_equal [[[:one], derivatives[:one]]], enumerator.to_a
      end
    end
  end
end
