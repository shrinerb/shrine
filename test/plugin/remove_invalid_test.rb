require "test_helper"
require "shrine/plugins/remove_invalid"

describe Shrine::Plugins::RemoveInvalid do
  before do
    @attacher = attacher { plugin :remove_invalid }
  end

  it "deletes and removes invalid cached files" do
    @attacher.class.validate { errors << :foo }
    @attacher.set(cached_file = @attacher.cache!(fakeio))
    refute cached_file.exists?
    assert_nil @attacher.get
  end

  it "deletes and removes invalid stored files" do
    @attacher.class.validate { errors << :foo }
    @attacher.set(stored_file = @attacher.store!(fakeio))
    refute stored_file.exists?
    assert_nil @attacher.get
  end

  it "assigns the previous attached file" do
    @attacher.set(previous_attachment = @attacher.store!(fakeio))
    @attacher.class.validate { errors << :foo }
    @attacher.set(cached_file = @attacher.cache!(fakeio))
    refute cached_file.exists?
    assert_equal previous_attachment, @attacher.get
  end

  it "removes the dirty state from the attacher" do
    @attacher.class.validate { errors << :foo }
    @attacher.set(cached_file = @attacher.cache!(fakeio))
    refute @attacher.changed?
  end

  it "doesn't remove the attachment if it isn't new" do
    @attacher.record.avatar_data = @attacher.store!(fakeio).to_json
    @attacher.class.validate { errors << :foo }
    @attacher.validate
    assert @attacher.get
  end
end
