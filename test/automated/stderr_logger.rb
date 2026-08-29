require_relative 'automated_init'

require 'hubbado/log/stderr_logger'
require 'stringio'

# What a person watching a run sees. Without it a tool whose diagnostics go elsewhere says nothing
# on the terminal, so a wait for a paid model call is silence for as long as the call takes.
context "StderrLogger" do
  subject = Log::Controls::Subject.example
  message = Log::Controls::Message.example

  # A stack that is recognisably one, and recognisably not anything else in the output.
  stacktrace = Log::Controls::Stacktrace.example

  # These scenarios say yes to everything: what is displayed at all is Level's and Tags'.
  def self.printed(severity, msg, data = nil, stacktrace = nil, tags = nil)
    io = StringIO.new

    shown do
      Log::StderrLogger.new(io: io).log(
        Log::Controls::Subject.example, severity, msg, data, stacktrace, tags
      )
    end

    io.string
  end

  def self.shown(level: nil, list: nil)
    configured_level = Log.config.level
    configured_tags = Log.config.tags

    Log.config.level = level || :trace
    Log.config.tags = list || '_all'

    yield
  ensure
    Log.config.level = configured_level
    Log.config.tags = configured_tags
  end

  context "The line itself" do
    printed = printed(:warn, message)

    test "Names the severity, the subject and what happened" do
      assert printed == "WARN #{subject}: #{message}\n"
    end
  end

  context "A line carrying nothing" do
    printed = printed(:info, message)

    # Data prints on its own line, and a nil printed rather than skipped would put the word "nil"
    # under every line that carried nothing — which is most of them.
    test "Prints one line, not a trailing nil" do
      refute printed.include?("nil")
    end
  end

  context "A line carrying data" do
    data = Log::Controls::Data.example

    printed = printed(:info, message, data)

    test "Prints the data below the line it belongs to" do
      assert printed.include?(data.inspect)
    end
  end

  # The stacktrace argument is the exception's own full_message, so honouring both prints it twice.
  context "A line carrying an exception" do
    exception = Log::Controls::Exception.example

    printed = printed(:error, message, exception, exception.full_message)

    test "Prints the backtrace, which is the part stderr is worth reading for" do
      assert printed.include?(exception.full_message)
    end

    test "Prints it once" do
      assert printed.scan(exception.full_message).length == 1
    end
  end

  # Called directly there is no rendered stacktrace to reuse, and the backtrace is the point.
  context "An exception with no stacktrace alongside it" do
    exception = Log::Controls::Exception.example

    printed = printed(:error, message, exception)

    test "renders the backtrace itself" do
      assert printed.include?(exception.full_message)
    end
  end

  # An error is logged just prior to raising, and the line alone does not say where from.
  context "An error carrying no exception" do
    printed = printed(:error, message, nil, stacktrace)

    test "Prints the stacktrace the logger synthesised" do
      assert printed.include?(stacktrace)
    end
  end

  # The logger synthesises one for warn too. A warning is a condition to examine rather than a
  # failure to trace, and thirty lines of stack under every warning in a sweep buries the log.
  context "A warning carrying no exception" do
    printed = printed(:warn, message, nil, stacktrace)

    test "Prints no stacktrace" do
      refute printed.include?(stacktrace)
    end
  end

  # The log system builds every handler with no arguments, so a required one fails at boot.
  context "Built the way the log system builds it" do
    captured = StringIO.new
    original = $stderr

    begin
      $stderr = captured

      Log::StderrLogger.new.log(subject, :warn, message)
    ensure
      $stderr = original
    end

    test "Writes to $stderr" do
      assert captured.string == "WARN #{subject}: #{message}\n"
    end
  end

  # A terminal is what an operator narrowing LOG_TAGS is narrowing, so this handler asks first.
  context "A message the operator did not ask to be shown" do
    io = StringIO.new

    shown(list: 'http') do
      Log::StderrLogger.new(io: io).log(subject, :warn, message, nil, nil, [:cache])
    end

    test "Is not printed" do
      assert io.string.empty?
    end
  end
end
