require "rack/test_app"

class Rack::TestApp::Wrapper
  %w[get post put delete head patch options trace].each do |verb|
    undef_method verb.upcase
    define_method(verb.upcase) { |path, **kwargs| request(verb.upcase.to_sym, path, **kwargs) }

    undef_method verb
    alias_method verb, verb.upcase
  end
end

module RackTestAppResultPatch
  def body_binary
    @body_binary ||= super
  end

  def body_text
    @body_text ||= super
  end

  def body_json
    @body_json ||= super
  end
end

Rack::TestApp::Result.send(:prepend, RackTestAppResultPatch)
