require "sucker_punch"

class DestroyJob
  include SuckerPunch::Job

  def perform(attacher_class, data)
    attacher = attacher_class.from_data(data)
    attacher.destroy
  end
end
