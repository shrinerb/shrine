require 'test_helper'
require 'shrine/plugins/pretty_location_with_id_partition'
require 'ostruct'

describe Shrine::Plugins::PrettyLocationWithIdPartition do
  module NameSpaced
    class OpenStruct < ::OpenStruct; end
  end

  before do
    @uploader = uploader { plugin :pretty_location_with_id_partition }
  end

  it 'uses context to build the directory' do
    uploaded_file = @uploader.upload(fakeio, record: OpenStruct.new(id: 123), name: :avatar)
    assert_match %r{^open_struct/000/000/123/avatar/[\w-]+$}, uploaded_file.id
  end

  it 'prepends version names to generated location' do
    uploaded_file = @uploader.upload(fakeio(filename: 'foo.jpg'), version: :thumb)
    assert_match %r{^thumb-[\w-]+\.jpg$}, uploaded_file.id
  end

  it 'includes only the inner class in location by default if underscore method is not available' do
    uploaded_file = @uploader.upload(fakeio, record: NameSpaced::OpenStruct.new(id: 123), name: :avatar)
    assert_match %r{^open_struct/000/000/123/avatar/[\w-]+$}, uploaded_file.id
  end

  it 'includes class namespace when :namespace is set' do
    @uploader.class.plugin :pretty_location_with_id_partition,
                           namespace: '_'
    uploaded_file = @uploader.upload(fakeio, record: NameSpaced::OpenStruct.new(id: 123), name: :avatar)
    assert_match %r{^name_spaced_open_struct/000/000/123/avatar/[\w-]+$}, uploaded_file.id
  end

  # change layout from default (:reversed_id_partition/:model) to :model/:id_partition
  it 'layouts' do
    @uploader.class.plugin :pretty_location_with_id_partition,
                           layout: [:reversed_id_partition, :model, :rest]
    uploaded_file = @uploader.upload(fakeio, record: OpenStruct.new(id: 123), name: :avatar)
    assert_match %r{^321/000/000/open_struct/avatar/[\w-]+$}, uploaded_file.id
  end
end
