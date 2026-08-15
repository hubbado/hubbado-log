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

    configured = Log.config.tags
    Log.config.tags = '_all'
    Hubbado::Log.log(:info, 'test', tag: :http)
    Log.config.tags = configured

    handler = Hubbado::Log.loggers.first

    test 'Filters on them' do
      assert handler.logged?
    end

    test 'Leaves the data alone' do
      assert handler.data.nil?
    end
  end
end
