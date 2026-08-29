require_relative 'automated_init'

# Which severities the operator is shown. Without a level every severity is displayed, so a
# tracing message written for a human watching one run is also printed in every unattended log the
# same code runs in.
context "Level" do
  # The configuration is the process's and every file in this suite shares it, so the level is put
  # back however the block ends. Without the ensure, one raising example would re-level every file
  # that runs after it.
  def self.at(level)
    configured = Log.config.level
    Log.config.level = level

    yield
  ensure
    Log.config.level = configured
  end

  def self.shows?(level, severity)
    at(level) { Log::Display.shows?(severity) }
  end

  context 'a message below the level' do
    test 'Is not displayed' do
      refute shows?(:info, :debug)
    end
  end

  # The most detailed there is: tracing program flow, which a class emits per iteration of a loop.
  # It sits under debug so that turning on the completion of secondary operations does not also
  # turn on a message per candidate in a set.
  context 'a trace message, under debug' do
    test 'At debug, is not displayed' do
      refute shows?(:debug, :trace)
    end

    test 'At trace, is displayed' do
      assert shows?(:trace, :trace)
    end

    test 'At trace, so is one above it' do
      assert shows?(:trace, :info)
    end
  end

  context 'a message at the level' do
    test 'Is displayed' do
      assert shows?(:info, :info)
    end
  end

  context 'a message above the level' do
    test 'Is displayed' do
      assert shows?(:info, :error)
    end
  end

  # The configuration is handed a level, never the environment it might have come from.
  # Reading LOG_LEVEL is Log's, done once, and what arrives here is only ever a value.
  context 'Configured level' do
    context 'Named a severity' do
      configuration = Log::Configuration.new(level: 'debug')

      test 'Is that severity' do
        assert configuration.level == :debug
      end
    end

    context 'Named nothing' do
      configuration = Log::Configuration.new

      test 'Is info, so tracing is off until somebody asks for it' do
        assert configuration.level == :info
      end
    end

    # LOG_LEVEL is Eventide's in hubbado_saas, where a dozen test_init files write "_min" into
    # it and an interactive start.sh writes "debug". Sharing the variable is deliberate, so a
    # vocabulary that is not ours has to be survivable rather than fatal.
    context 'Named something that is not a severity' do
      configuration = Log::Configuration.new(level: '_min')

      test 'Falls back to info rather than raising' do
        assert configuration.level == :info
      end
    end

    context 'Set after construction' do
      configuration = Log::Configuration.new(level: 'debug')
      configuration.level = :warn

      test 'Is what was set' do
        assert configuration.level == :warn
      end
    end
  end
end
