require "test_helper"

describe "plugin system" do
  describe "Shrine.plugin" do
    describe "when called globally" do
      before do
        @components = [Shrine, Shrine::UploadedFile, Shrine::Attachment, Shrine::Attacher]

        @components.each do |component|
          component::InstanceMethods.send(:define_method, :foo) { :foo }
          component::ClassMethods.send(:define_method, :foo) { :foo }
        end

        module TestPlugin
          module ClassMethods;           def foo; :plugin_foo; end; end
          module InstanceMethods;        def foo; :plugin_foo; end; end
          module FileClassMethods;       def foo; :plugin_foo; end; end
          module FileMethods;            def foo; :plugin_foo; end; end
          module AttacherClassMethods;   def foo; :plugin_foo; end; end
          module AttacherMethods;        def foo; :plugin_foo; end; end
          module AttachmentClassMethods; def foo; :plugin_foo; end; end
          module AttachmentMethods;      def foo; :plugin_foo; end; end
        end
      end

      after do
        @components.each do |component|
          component::InstanceMethods.send(:undef_method, :foo)
          component::ClassMethods.send(:undef_method, :foo)
        end

        TestPlugin.constants.each do |name|
          mod = TestPlugin.const_get(name)
          mod.send(:undef_method, :foo)
        end
      end

      it "allows the plugin to override base methods of core classes" do
        assert_equal :foo, Shrine.foo
        assert_equal :foo, Shrine.allocate.foo
        assert_equal :foo, Shrine::UploadedFile.foo
        assert_equal :foo, Shrine::UploadedFile.allocate.foo
        assert_equal :foo, Shrine::Attacher.foo
        assert_equal :foo, Shrine::Attacher.allocate.foo
        assert_equal :foo, Shrine::Attachment.foo
        assert_equal :foo, Shrine::Attachment.allocate.foo

        Shrine.plugin TestPlugin

        assert_equal :plugin_foo, Shrine.foo
        assert_equal :plugin_foo, Shrine.allocate.foo
        assert_equal :plugin_foo, Shrine::UploadedFile.foo
        assert_equal :plugin_foo, Shrine::UploadedFile.allocate.foo
        assert_equal :plugin_foo, Shrine::Attacher.foo
        assert_equal :plugin_foo, Shrine::Attacher.allocate.foo
        assert_equal :plugin_foo, Shrine::Attachment.foo
        assert_equal :plugin_foo, Shrine::Attachment.allocate.foo
      end
    end
  end
end
