require "test_helper"
require "shrine/plugins/metadata_attributes"

describe Shrine::Plugins::MetadataAttributes do
  before do
    @attacher = attacher { plugin :metadata_attributes }
  end

  it "writes values to metadata attributes when file is assigned" do
    @attacher.record.singleton_class.instance_eval { attr_accessor :avatar_size, :avatar_type }
    @attacher.class.metadata_attributes size: :size, mime_type: :type
    @attacher.assign(fakeio("file", content_type: "text/plain"))
    assert_equal 4,            @attacher.record.avatar_size
    assert_equal "text/plain", @attacher.record.avatar_type
  end

  it "set metadata attributes to nil when file is removed" do
    @attacher.record.singleton_class.instance_eval { attr_accessor :avatar_size, :avatar_type }
    @attacher.class.metadata_attributes size: :size, mime_type: :type
    @attacher.assign(fakeio("file", content_type: "text/plain"))
    @attacher.assign(nil)
    assert_nil @attacher.record.avatar_size
    assert_nil @attacher.record.avatar_type
  end

  it "allows specifying full record attribute name" do
    @attacher.record.singleton_class.instance_eval { attr_accessor :original_filename }
    @attacher.class.metadata_attributes :filename => "original_filename"
    @attacher.assign(fakeio("image", filename: "nature.jpg"))
    assert_equal "nature.jpg", @attacher.record.original_filename
    @attacher.assign(nil)
    assert_nil @attacher.record.original_filename
  end

  it "allows configuring mappings on plugin initialization" do
    @attacher.record.singleton_class.instance_eval { attr_accessor :avatar_size, :avatar_type }
    @attacher.shrine_class.plugin :metadata_attributes, :size => :size, :mime_type => :type
    @attacher.assign(fakeio("file", content_type: "text/plain"))
    assert_equal 4,            @attacher.record.avatar_size
    assert_equal "text/plain", @attacher.record.avatar_type
  end

  it "doesn't raise errors if metadata attribute is missing" do
    @attacher.record.singleton_class.instance_eval { attr_accessor :avatar_size }
    @attacher.class.metadata_attributes size: :size, mime_type: :type
    @attacher.assign(fakeio("file", content_type: "text/plain"))
    assert_equal 4, @attacher.record.avatar_size
  end
end
