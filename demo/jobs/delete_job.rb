require "sucker_punch"

class DeleteJob
  include SuckerPunch::Job

  def perform(data)
    Shrine::Attacher.delete(data)  # Required by `backgrounding` plugin
  end
end
