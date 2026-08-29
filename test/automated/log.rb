require_relative 'automated_init'

context "Log" do
  test 'Log to configured loggers' do
    Hubbado::Log.configuration do |config|
      config.loggers = [Log::Controls::LogHandler]
    end

    Hubbado::Log.log(:info, 'test')

    logger = Hubbado::Log.loggers.first

    assert logger.severity == :info
    assert logger.message == 'test'
    assert logger.data.nil?
    assert logger.stacktrace.nil?
  end

  # The module-level entry point takes what a logger's does. Without the keywords named here,
  # Ruby folds them into a positional hash and they arrive as the message's data — which a
  # handler hands to Rollbar as the exception argument.
  context 'Naming tags' do
    Hubbado::Log.configuration do |config|
      config.loggers = [Log::Controls::LogHandler]
    end

    Hubbado::Log.log(:info, 'test', tag: :http)

    handler = Hubbado::Log.loggers.first

    test 'Reaches the handler with them named' do
      assert handler.logged?
    end

    test 'Leaves the data alone' do
      assert handler.data.nil?
    end
  end

  # A block is free to add to the list it is handed rather than replace it, so what a handler
  # was told before the change is not what the process reads back after it.
  context 'Reconfiguring' do
    Hubbado::Log.configuration do |config|
      config.loggers = [Log::Controls::LogHandler]
    end

    built = Hubbado::Log.loggers.first

    Hubbado::Log.configuration do |config|
      config.loggers << Log::Controls::LogHandler
    end

    test 'Builds the handlers again' do
      refute Hubbado::Log.loggers.first.equal?(built)
    end

    Hubbado::Log.configuration do |config|
      config.loggers = [Log::Controls::LogHandler]
    end
  end
end
