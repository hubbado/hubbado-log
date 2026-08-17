require_relative 'automated_init'

# Rails is not loaded here and is not a dependency of this gem. Defining it is safe: test_bench
# runs each file in a forked process, so the constant does not reach any other spec.
module Rails
  def self.logger = @logger ||= nil
  class << self; attr_writer :logger; end
end

require 'hubbado/log/rails_logger'

# What a Rails application's log receives. Two applications had hand-rolled this and the copies
# had drifted — one mapped the gem's trace severity onto a level Rails has, the other raised.
context "RailsLogger" do
  subject = Log::Controls::Subject.example
  message = Log::Controls::Message.example

  stacktrace = Log::Controls::Stacktrace.example

  def self.written(severity, msg, data = nil, stacktrace = nil)
    rails_logger = Log::Controls::RailsLogger.example

    handler = Log::RailsLogger.new
    handler.rails_logger = rails_logger
    handler.log(Log::Controls::Subject.example, severity, msg, data, stacktrace)

    rails_logger.lines
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

  # The drift between the two copies, and a real failure: Rails has no logger method below
  # debug, so a copy passing trace straight through raises NoMethodError on the first trace
  # line it is handed.
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

  # Hubbado::Log.loggers is config.loggers.map(&:new), so the log system builds every handler
  # itself with no arguments.
  context "Built the way the log system builds it" do
    rails_logger = Log::Controls::RailsLogger.example
    Rails.logger = rails_logger

    Log::RailsLogger.new.log(subject, :warn, message)

    test "takes none, and writes to Rails.logger" do
      assert rails_logger.lines == [[:warn, "#{subject}: #{message}"]]
    end
  end
end
