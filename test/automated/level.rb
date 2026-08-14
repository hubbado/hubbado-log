require_relative 'automated_init'

# Which lines reach a handler at all. Without a level the logger fans every severity to every
# handler, so a tracing line written for a human watching one run is also written to every
# unattended log the same code runs in.
context "Level" do
  message = Log::Controls::Message.example

  def self.logger(handler, level:)
    Log::Logger.new(Log::Controls::Subject.example, handler, level: level)
  end

  context 'a line below the level' do
    handler = Log::Controls::LogHandler.new

    logger(handler, level: :info).debug(message)

    test 'Reaches no handler' do
      assert handler.severity.nil?
    end
  end

  context 'a line at the level' do
    handler = Log::Controls::LogHandler.new

    logger(handler, level: :info).info(message)

    test 'Reaches the handler' do
      assert handler.severity == :info
    end
  end

  context 'a line above the level' do
    handler = Log::Controls::LogHandler.new

    logger(handler, level: :info).error(message)

    test 'Reaches the handler' do
      assert handler.severity == :error
    end
  end

  # An invalid severity is still the caller's mistake. The level decides what is printed, not
  # what may be said, so lowering it must not turn a typo into silence.
  context 'an invalid severity, below the level' do
    handler = Log::Controls::LogHandler.new

    test 'Raises an exception' do
      assert_raises(ArgumentError) do
        logger(handler, level: :error).log('DEADBEEF', message)
      end
    end
  end

  context 'Configured level' do
    context 'LOG_LEVEL naming a severity' do
      configuration = Log::Configuration.new(env: { 'LOG_LEVEL' => 'debug' })

      test 'Is the level' do
        assert configuration.level == :debug
      end
    end

    context 'LOG_LEVEL unset' do
      configuration = Log::Configuration.new(env: {})

      test 'Is info, so tracing is off until somebody asks for it' do
        assert configuration.level == :info
      end
    end

    # LOG_LEVEL is Eventide's in hubbado_saas, where a dozen test_init files write "_min" into
    # it and an interactive start.sh writes "debug". Sharing the variable is deliberate, so a
    # vocabulary that is not ours has to be survivable rather than fatal.
    context 'LOG_LEVEL naming something that is not a severity' do
      configuration = Log::Configuration.new(env: { 'LOG_LEVEL' => '_min' })

      test 'Falls back to info rather than raising' do
        assert configuration.level == :info
      end
    end

    context 'Set directly' do
      configuration = Log::Configuration.new(env: { 'LOG_LEVEL' => 'debug' })
      configuration.level = :warn

      test 'Overrides the environment' do
        assert configuration.level == :warn
      end
    end
  end

  # A logger built without one is every logger the gem builds itself — Log.configure hands no
  # level, so the configured one is what reaches a class using the Dependency module.
  #
  # The configuration is process-wide and every file in this suite shares it, so it is put back
  # before anything else reads it.
  context 'A logger named no level' do
    handler = Log::Controls::LogHandler.new
    configured = Log.config.level

    Log.config.level = :warn
    Log::Logger.new(Log::Controls::Subject.example, handler).info(message)
    Log.config.level = configured

    test 'Takes the configured level' do
      assert handler.severity.nil?
    end
  end
end
