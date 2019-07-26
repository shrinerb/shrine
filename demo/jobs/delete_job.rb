require "sucker_punch"

class DeleteJob
  include SuckerPunch::Job

  def perform(data)
    attacher = Shrine::Attacher.from_data(data)
    attacher.destroy
  end
end
