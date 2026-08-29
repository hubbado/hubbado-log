require_relative 'automated_init'

require 'hubbado/log/rails_logger'

# What a Rails application's log receives.
context "RailsLogger" do
  subject = Log::Controls::Subject.example
  message = Log::Controls::Message.example

  stacktrace = Log::Controls::Stacktrace.example

  # These scenarios say yes to everything: what is displayed at all is Level's and Tags'.
  def self.written(severity, msg, data = nil, stacktrace = nil, tags = nil)
    rails_logger = Log::Controls::RailsLogger.example

    DisplaySettings.showing do
      Log::RailsLogger.new(rails_logger: rails_logger)
        .log(Log::Controls::Subject.example, severity, msg, data, stacktrace, tags)
    end

    rails_logger.lines
  end

  # Rails is not loaded here and is not a dependency of this gem, so the constant has to be
  # stood up to read the default at all — and taken down again, because every spec file in a run
  # shares one process and a leaked ::Rails would be defined for all of them.
  def self.with_rails(rails_logger)
    Object.const_set(:Rails, Module.new do
      define_singleton_method(:logger) { rails_logger }
    end)

    yield
  ensure
    Object.send(:remove_const, :Rails)
  end

  context "The line itself" do
    lines = written(:warn, message)

    test "names the class it came from and what happened, at the severity it was written at" do
      assert lines == [[:warn, "#{subject}: #{message}"]]
    end
  end

  context "A line carrying data" do
    data = Log::Controls::Data.example

    lines = written(:info, message, data)

    test "writes the data below the line it belongs to, at the same severity" do
      assert lines.length == 2
      assert lines.last == [:info, data.inspect]
    end
  end

  context "A line carrying a stacktrace" do
    lines = written(:error, message, nil, stacktrace)

    # Unlike a terminal, a Rails log is read after the fact and by machine as often as by a
    # person, so there is no reason to withhold frames from it.
    test "writes it, whatever the severity" do
      assert lines.last == [:error, stacktrace]
    end
  end

  context "A line carrying neither" do
    lines = written(:info, message)

    test "writes one line, not a trailing nil" do
      assert lines.length == 1
    end
  end

  # Rails has no logger method below debug, so a handler passing trace straight through raises
  # NoMethodError on the first trace line it is handed.
  context "A trace line, which Rails has no level for" do
    lines = written(:trace, message)

    test "is written as debug rather than raising" do
      assert lines == [[:debug, "#{subject}: #{message}"]]
    end
  end

  context "Every other severity" do
    %i[debug info warn error fatal unknown].each do |severity|
      context severity.to_s do
        lines = written(severity, message)

        test "is written as itself" do
          assert lines.first.first == severity
        end
      end
    end
  end

  # The logger renders an exception's backtrace into the stacktrace argument as well as passing
  # the exception as data, so a handler writing both writes the message twice.
  context "A line carrying an exception" do
    exception = Log::Controls::Exception.example

    lines = written(:error, message, exception, exception.full_message)

    test "writes the backtrace" do
      assert lines.last == [:error, exception.full_message]
    end

    test "writes it once, rather than the inspect and the backtrace both" do
      assert lines.length == 2
      refute(lines.any? { |_, written| written == exception.inspect })
    end
  end

  # A handler called directly rather than through the logger has no rendered stacktrace to
  # reuse, and the backtrace is the part a Rails log is worth reading for.
  context "An exception with no stacktrace alongside it" do
    exception = Log::Controls::Exception.example

    lines = written(:error, message, exception)

    test "renders the backtrace itself" do
      assert lines.last == [:error, exception.full_message]
    end
  end

  # Hubbado::Log.loggers is config.loggers.map(&:new), so the log system builds every handler
  # itself with no arguments.
  context "Built the way the log system builds it" do
    rails_logger = Log::Controls::RailsLogger.example

    with_rails(rails_logger) do
      Log::RailsLogger.new.log(subject, :warn, message)
    end

    test "takes none, and writes to Rails.logger" do
      assert rails_logger.lines == [[:warn, "#{subject}: #{message}"]]
    end
  end

  # Read after the fact rather than watched, but still what an operator narrows, so it asks too.
  context "A message the operator did not ask to be shown" do
    rails_logger = Log::Controls::RailsLogger.example

    DisplaySettings.showing(tags: 'http') do
      Log::RailsLogger.new(rails_logger: rails_logger)
        .log(subject, :warn, message, nil, nil, [:cache])
    end

    test "Is not written" do
      assert rails_logger.lines.empty?
    end
  end
end
