require "sucker_punch"

class DestroyJob
  include SuckerPunch::Job

  def perform(attacher_class, data)
    attacher = Object.const_get(attacher_class.to_s).from_data(data)
    attacher.destroy
  end
end
