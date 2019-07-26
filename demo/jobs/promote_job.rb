require "sucker_punch"

class PromoteJob
  include SuckerPunch::Job

  def perform(record_class, record_id, name, data)
    record_class = Object.const_get(record_class)
    record       = record_class.with_pk!(record_id)

    attacher = Shrine::Attacher.retrieve(model: record, name: name, data: data)
    attacher.atomic_promote
  rescue Shrine::AttachmentChanged
    # attachment has changed, so nothing to do
  rescue Sequel::NoMatchingRow, Sequel::NoExistingObject
    # record has been deleted, so nothing to do
  end
end
