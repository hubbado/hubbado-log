require_relative 'automated_init'

context "Log" do
  context "Dependency Module" do
    Example = Class.new do
      include Log::Dependency
    end

    obj = Example.new

    test "Adds the logger attribute" do
      assert(obj.respond_to? :logger)
    end

    test "Logs" do
      refute_raises do
        obj.logger.log(:info, 'some message')
      end
    end

    test "Sets subject" do
      assert obj.logger.subject == 'Example'
    end
  end

  # A subclass gets a Dependency module of its own, so a component can name itself where its
  # classes take their logger from. It writes through the handlers the process was configured
  # with, the same ones the root class hands out.
  context "Subclass" do
    Component = Class.new(Hubbado::Log)

    Receiver = Class.new do
      include Component::Dependency
    end

    Hubbado::Log.configuration do |config|
      config.loggers = [Log::Controls::LogHandler]
    end

    obj = Receiver.new
    obj.logger.info('some message')

    test "Writes" do
      assert Hubbado::Log.loggers.first.logged?(:info)
    end

    test "Through the handlers the process was configured with" do
      assert Component.loggers.equal?(Hubbado::Log.loggers)
    end
  end
end
