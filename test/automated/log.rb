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
end
