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
end
