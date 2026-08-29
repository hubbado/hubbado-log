require_relative 'automated_init'

context "Logger" do
  handler = Log::Controls::LogHandler.new
  subject = Log::Controls::Subject.example

  # What #log hands a handler, across every severity there is. The logger fans out whatever it
  # is given: which messages an operator is shown at all is Display's.
  logger = Log::Logger.new(subject, handler)

  context '#log' do
    message = Log::Controls::Message.example

    context 'with an invalid severity' do
      severity = 'DEADBEEF'

      test "Raises an exception" do
        assert_raises(ArgumentError) do
          logger.log(severity, message)
        end
      end
    end

    %i[debug info].each do |severity|
      context "when the severity is #{severity}" do
        test 'Passes details without a stacktrace to the log handler' do
          logger.log(severity, message)

          assert handler.subject == subject
          assert handler.severity == severity
          assert handler.message == message
          assert handler.data.nil?
          assert handler.stacktrace.nil?
        end
      end
    end

    %i[warn error fatal unknown].each do |severity|
      # TODO: Use a control
      # stacktrace = Array.new(10) { FFaker::HipsterIpsum.sentence }

      context "when the severity is #{severity}" do
        test 'Passes details with a stacktrace to the log handler' do
          logger.log(severity, message)

          assert handler.subject == subject
          assert handler.severity == severity
          assert handler.message == message
          assert handler.data.nil?
          # TODO: We cannot currently override Kernel.caller in TestBench
          # Should we printing stracktraces at all?
          # assert handler.stacktrace == stacktrace.join("\n")
        end
      end
    end

    # #log takes a String as readily as a symbol and passes on what it was given, so the severity
    # is compared as a symbol wherever it decides anything. Compared raw, a failure written as a
    # String reaches Rollbar with no stack under it — an item nobody can act on, filed as though
    # nothing were wrong with it.
    context 'A severity named as a String' do
      %w[warn error fatal unknown].each do |severity|
        context severity do
          test 'Is given a stacktrace, as the symbol is' do
            logger.log(severity, message)

            refute handler.stacktrace.nil?
          end
        end
      end

      context 'below the stacktrace severities' do
        test 'Is given none, as the symbol is' do
          logger.log('info', message)

          assert handler.stacktrace.nil?
        end
      end
    end

    context "Severity methods" do
      Log::SEVERITIES.each_key do |severity|
        context "##{severity}" do
          logger.send severity, message

          test "Sets severity" do
            assert handler.severity == severity
          end
        end
      end
    end

    # A handler is told what the message was tagged with, which is how one decides whether the
    # operator asked to be shown it, and what a handler recording somewhere structured files under.
    context "Tags" do
      tagged = Log::Controls::LogHandler.new
      tagged_logger = Log::Logger.new(subject, tagged)

      context 'named singly' do
        tagged_logger.info(message, tag: :http)

        test 'Reach the handler' do
          assert tagged.tags == [:http]
        end
      end

      context 'named as a list' do
        tagged_logger.info(message, tags: %i[cache http])

        test 'Reach the handler' do
          assert tagged.tags == %i[cache http]
        end
      end

      context 'not named at all' do
        tagged_logger.info(message)

        test 'Reach the handler as none' do
          assert tagged.tags == []
        end
      end

      # The operator's list is symbols, because LOG_TAGS is parsed into them. A String reaching a
      # handler as itself would match nothing, and its message would go missing with nothing said
      # about it — the one failure this gem must never produce quietly.
      context 'named as a String' do
        tagged_logger.info(message, tag: 'cache')

        test 'Reach the handler as the symbol the list is matched on' do
          assert tagged.tags == [:cache]
        end
      end
    end

    context "Data" do
      context "Without data" do
        severity = :info

        logger.log(severity, message, nil)

        test 'Passes nil data to the log handler' do
          assert handler.data.nil?
        end
      end

      context 'with regular data' do
        severity =  :info
        data = Log::Controls::Data.example

        logger.log(severity, message, data)

        test 'Passes data to the log handler' do
          assert handler.data == data
        end

        test 'Does not pass a stractrace' do
          assert handler.stacktrace.nil?
        end
      end

      context 'when the data is an exception' do
        severity = :error
        exception = Log::Controls::Exception.example

        logger.log(severity, message, exception)

        test 'Passes data to the log handler' do
          assert handler.data == exception
        end

        test 'Passes the Exception.full_message as the stacktrace' do
          assert handler.stacktrace == exception.full_message
        end
      end
    end
  end
end
