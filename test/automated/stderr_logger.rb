require_relative 'automated_init'

require 'hubbado/log/stderr_logger'
require 'stringio'

# What a person watching a run sees. A tool whose diagnostics go somewhere else — onto a card, or
# into an envelope on stdout — says nothing at all on a terminal without this, so a wait for a paid
# model call is a terminal saying nothing for as long as the call takes.
context "StderrLogger" do
  subject = Log::Controls::Subject.example
  message = Log::Controls::Message.example

  # A stack that is recognisably one, and recognisably not anything else in the output.
  stacktrace = Log::Controls::Stacktrace.example

  # The handler asks Display whether the operator wanted to be shown the message, so these
  # scenarios say yes to everything: what is displayed at all is Level's and Tags'.
  def self.printed(severity, msg, data = nil, stacktrace = nil, tags = [])
    io = StringIO.new

    shown do
      Log::StderrLogger.new(io: io).log(
        Log::Controls::Subject.example, severity, msg, data, stacktrace, tags
      )
    end

    io.string
  end

  def self.shown(level: :trace, list: '_all')
    configured_level = Log.config.level
    configured_tags = Log.config.tags

    Log.config.level = level
    Log.config.tags = list

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

  # The logger sets the stacktrace to the exception's own full_message, so the two arguments carry
  # the same string and a handler honouring both would print the backtrace twice.
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

  # A handler called directly rather than through the logger has no rendered stacktrace to reuse,
  # and the backtrace is the part stderr is worth reading for.
  context "An exception with no stacktrace alongside it" do
    exception = Log::Controls::Exception.example

    printed = printed(:error, message, exception)

    test "renders the backtrace itself" do
      assert printed.include?(exception.full_message)
    end
  end

  # An error is logged just prior to raising, so it is a failure somebody has to find, and the
  # line alone does not say where it came from.
  context "An error carrying no exception" do
    printed = printed(:error, message, nil, stacktrace)

    test "Prints the stacktrace the logger synthesised" do
      assert printed.include?(stacktrace)
    end
  end

  # The logger synthesises a caller stack for warn as well. A warning is a condition to examine
  # rather than a failure to trace, and its message already names the field and value — so thirty
  # lines of Ruby stack under every warning in a sweep is the log made unreadable to solve a
  # problem stderr does not have.
  context "A warning carrying no exception" do
    printed = printed(:warn, message, nil, stacktrace)

    test "Prints no stacktrace" do
      refute printed.include?(stacktrace)
    end
  end

  # Hubbado::Log.loggers is config.loggers.map(&:new), so the log system builds every handler
  # itself with no arguments. An initialize that grew a required one would fail at process start.
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

  # A terminal is the thing an operator narrowing LOG_TAGS is narrowing, so this handler asks
  # before it writes. Without that, narrowing the log would print everything regardless.
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
