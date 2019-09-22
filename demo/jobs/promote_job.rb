require "sucker_punch"

class PromoteJob
  include SuckerPunch::Job

  def perform(attacher_class, record_class, record_id, name, file_data)
    record   = record_class.with_pk!(record_id)
    attacher = attacher_class.retrieve(model: record, name: name, file: file_data)
    attacher.create_derivatives
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged
    # attachment has changed, so nothing to do
  rescue Sequel::NoMatchingRow, Sequel::NoExistingObject
    # record has been deleted, so nothing to do
  end
end
