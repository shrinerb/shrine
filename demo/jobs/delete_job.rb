require "sucker_punch"

class DeleteJob
  include SuckerPunch::Job

  def perform(data)
    Shrine::Attacher.delete(data)  # finish deleting (`backgrounding` plugin)
  end
end
