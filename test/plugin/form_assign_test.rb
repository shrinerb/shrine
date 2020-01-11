require "test_helper"
require "shrine/plugins/form_assign"

describe Shrine::Plugins::FormAssign do
  before do
    @attacher = attacher { plugin :form_assign }
    @attacher = @attacher.class.from_entity(entity(file_data: nil), :file)
  end

  describe "Attacher" do
    describe "#form_assign" do
      describe "with raw file" do
        it "attaches file" do
          @attacher.form_assign({ "file" => fakeio })

          assert @attacher.attached?
          assert @attacher.changed?
        end

        it "returns params" do
          result = @attacher.form_assign({ "file" => fakeio, "foo" => "bar" })

          assert_equal Hash[file: @attacher.file.to_json, "foo" => "bar"], result
        end

        it "returns attributes" do
          result = @attacher.form_assign({ "file" => fakeio, "foo" => "bar" }, result: :attributes)

          assert_equal Hash[file_data: @attacher.column_data, "foo" => "bar"], result
        end
      end

      describe "with cached file" do
        before do
          @cached_file = @attacher.upload(fakeio, :cache)
        end

        it "attaches file" do
          @attacher.form_assign({ "file" => @cached_file.to_json })

          assert @attacher.attached?
          assert @attacher.changed?

          assert_equal @cached_file, @attacher.file
        end

        it "returns params" do
          result = @attacher.form_assign({ "file" => @cached_file.to_json, "foo" => "bar" })

          assert_equal Hash[file: @attacher.file.to_json, "foo" => "bar"], result
        end

        it "returns attributes" do
          result = @attacher.form_assign({ "file" => @cached_file.to_json, "foo" => "bar" }, result: :attributes)

          assert_equal Hash[file_data: @attacher.column_data, "foo" => "bar"], result
        end
      end

      describe "with nil file" do
        before do
          @attacher.file = @attacher.upload(fakeio)
        end

        it "attaches file" do
          @attacher.form_assign({ "file" => nil })

          refute @attacher.attached?
          assert @attacher.changed?
        end

        it "returns params" do
          result = @attacher.form_assign({ "file" => nil, "foo" => "bar" })

          assert_equal Hash[file: nil, "foo" => "bar"], result
        end

        it "returns attributes" do
          result = @attacher.form_assign({ "file" => nil, "foo" => "bar" }, result: :attributes)

          assert_equal Hash[file_data: nil, "foo" => "bar"], result
        end
      end

      describe "with no file" do
        before do
          @attacher.file = @attacher.upload(fakeio)
        end

        it "attaches nothing" do
          @attacher.form_assign({ "file" => "" })

          assert @attacher.attached?
          refute @attacher.changed?
        end

        it "returns params" do
          result = @attacher.form_assign({ "file" => "", "foo" => "bar" })

          assert_equal Hash["foo" => "bar"], result
        end

        it "returns attributes" do
          result = @attacher.form_assign({ "file" => "", "foo" => "bar" }, result: :attributes)

          assert_equal Hash["foo" => "bar"], result
        end
      end
    end
  end
end
