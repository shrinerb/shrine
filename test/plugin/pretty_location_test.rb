require "test_helper"
require "shrine/plugins/pretty_location"

describe Shrine::Plugins::PrettyLocation do
  before do
    @uploader = uploader { plugin :pretty_location }
    @shrine   = @uploader.class
  end

  class NameSpaced
    class Entity < Struct.new(:id)
    end
  end

  describe "Shrine" do
    describe "#generate_location" do
      it "prepends record identifier and attachmet name" do
        location = @uploader.generate_location(
          fakeio,
          record: entity(id: 123),
          name:   :file,
        )

        assert_match %r{^123/file/\w+$}, location
      end

      it "allows overriding :identifier on the plugin level" do
        @shrine.plugin :pretty_location, identifier: :uuid

        location = @uploader.generate_location(
          fakeio,
          record: entity(uuid: "xyz"),
          name: :file,
        )

        assert_match %r{^xyz/file/\w+$}, location
      end

      it "prepends version name to basic location" do
        location = @uploader.generate_location(
          fakeio,
          version: :thumb
        )

        assert_match %r{^thumb-\w+$}, location

        location = @uploader.generate_location(
          fakeio,
          version: [:thumb, :medium]
        )

        assert_match %r{^thumb-medium-[\w-]+$}, location
      end

      it "prepends derivative name to basic location" do
        location = @uploader.generate_location(
          fakeio,
          derivative: :thumb
        )

        assert_match %r{^thumb-\w+$}, location

        location = @uploader.generate_location(
          fakeio,
          derivative: [:thumb, :medium]
        )

        assert_match %r{^thumb-medium-[\w-]+$}, location
      end

      it "includes only the inner class by default" do
        location = @uploader.generate_location(
          fakeio,
          record: NameSpaced::Entity.new(123),
          name: :file,
        )

        assert_match %r{^entity/123/file/\w+$}, location
      end

      it "includes class namespace when :namespace is set" do
        @shrine.plugin :pretty_location, namespace: "_"

        location = @uploader.generate_location(
          fakeio,
          record: NameSpaced::Entity.new(123),
          name: :file,
        )

        assert_match %r{^namespaced_entity/123/file/\w+$}, location
      end

      it "transform class name with underscore when :class_transform is set to underscore" do
        @shrine.plugin :pretty_location, class_transform: :underscore

        location = @uploader.generate_location(
          fakeio,
          record: NameSpaced::Entity.new(123),
          name: :file,
        )

        assert_match %r{^name_spaced/entity/123/file/\w+$}, location
      end

      it "transform class name with given proc when :class_transform is a proc" do
        @shrine.plugin :pretty_location, class_transform: ->(class_name){ "prefix_" + class_name.underscore }

        location = @uploader.generate_location(
          fakeio,
          record: NameSpaced::Entity.new(123),
          name: :file,
        )

        assert_match %r{^prefix_name_spaced/entity/123/file/\w+$}, location
      end


      it "fails when record does not respond to default identifier" do
        assert_raises NoMethodError do
          @uploader.generate_location(
            fakeio,
            record: entity({}),
            name:   :file,
          )
        end
      end
    end
  end
end
