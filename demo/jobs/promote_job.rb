require "sucker_punch"

class PromoteJob
  include SuckerPunch::Job

  def perform(data)
    Shrine::Attacher.promote(data)  # Required by `backgrounding` plugin
  end
end
