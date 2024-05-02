require_relative 'automated_init'
require 'ffaker'

context "Logger" do
  handler = Log::Controls::LogHandler.new
  logger = Log::Logger.new(handler)

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

          assert handler.severity == severity
          assert handler.message == message
          assert handler.data.nil?
          # TODO: We cannot currently override Kernel.caller in TestBench
          # Should we printing stracktraces at all?
          # assert handler.stacktrace == stacktrace.join("\n")
        end
      end
    end

    context 'with regular data' do
      severity =  :info
      data = Log::Controls::Data.example

      test 'Passes details with data to the log handler' do
        logger.log(severity, message, data)

        assert handler.severity == severity
        assert handler.message == message
        assert handler.data == data
        assert handler.stacktrace.nil?
      end
    end

    context 'when the data is an exception' do
      severity = :error

      exception = Log::Controls::Exception.example
      test 'Passes the Exception.full_message as the stacktrace' do
        logger.log(severity, message, exception)

        assert handler.severity == severity
        assert handler.message == message
        assert handler.data == exception
        assert handler.stacktrace == exception.full_message
      end
    end
  end
end
