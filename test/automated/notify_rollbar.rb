require_relative 'automated_init'

require 'hubbado/log/notify_rollbar'

# What reaches Rollbar, and what a person triaging an item is given to work with. Two projects
# had hand-rolled this identically, and both dropped the subject and the stacktrace.
context "NotifyRollbar" do
  subject = Log::Controls::Subject.example
  message = Log::Controls::Message.example

  stacktrace = "lib/scanning.rb:14:in 'sweep'\nlib/cli.rb:3:in 'call'"

  # Records what it was handed rather than sending it. Rollbar's own entry points scan their
  # arguments by type, which is the behaviour under test, so the double keeps them positional
  # and unread.
  recorder = Class.new do
    def calls = @calls ||= []

    def warn(*args) = calls << [:warn, args]
    def error(*args) = calls << [:error, args]
  end

  def self.notifying(severity, msg, data = nil, stacktrace = nil, notifier:)
    handler = Log::NotifyRollbar.new
    handler.notifier = notifier
    handler.log(Log::Controls::Subject.example, severity, msg, data, stacktrace)

    notifier.calls
  end

  context "Severities Rollbar has a level for" do
    context "a warning" do
      calls = notifying(:warn, message, notifier: recorder.new)

      test "reaches Rollbar as a warning, not as an error" do
        assert calls.length == 1
        assert calls.first.first == :warn
      end
    end

    # Rollbar has no level above error, so the two severities above warn share it.
    %i[error fatal unknown].each do |severity|
      context severity.to_s do
        calls = notifying(severity, message, notifier: recorder.new)

        test "reaches Rollbar as an error" do
          assert calls.map(&:first) == [:error]
        end
      end
    end
  end

  context "Severities below a warning" do
    calls = notifying(:info, message, notifier: recorder.new)

    test "are running commentary, and are not incidents" do
      assert calls.empty?
    end
  end

  # The extra hash, which is where everything that is not the message or the exception travels.
  def self.extra_from(calls)
    calls.first.last.find { |argument| argument.is_a?(Hash) }
  end

  context "The line itself" do
    calls = notifying(:warn, message, notifier: recorder.new)

    test "carries the message" do
      assert calls.first.last.include?(message)
    end

    # Rollbar groups on the message, so an item that does not say which class wrote it groups
    # every class sharing a wording into one incident.
    test "names the class that logged it" do
      assert extra_from(calls).fetch("subject") == subject
    end
  end

  context "A line carrying an exception" do
    exception = Log::Controls::Exception.example

    calls = notifying(:error, message, exception, exception.full_message, notifier: recorder.new)

    test "hands Rollbar the exception itself, which is what it groups and traces on" do
      assert calls.first.last.include?(exception)
    end

    # Rollbar reads the backtrace off the exception. Sending it again as data would put the
    # same frames in the item twice.
    test "does not also send the stacktrace as data" do
      refute extra_from(calls).key?("stacktrace")
    end
  end

  context "An error carrying no exception" do
    calls = notifying(:error, message, nil, stacktrace, notifier: recorder.new)

    test "sends the stacktrace the logger synthesised, which is all the item has" do
      assert extra_from(calls).fetch("stacktrace") == stacktrace
    end
  end

  # Rollbar scans its arguments by type and keeps the last hash it finds, discarding any
  # earlier one. So the line's own data and the handler's fields have to arrive as one hash.
  context "A line carrying a hash" do
    calls = notifying(:warn, message, { "record_id" => "rec_1" }, notifier: recorder.new)

    test "reaches the item rather than being displaced by the handler's own fields" do
      assert extra_from(calls).fetch("record_id") == "rec_1"
      assert extra_from(calls).fetch("subject") == subject
    end

    test "arrives as a single hash, because a second one would replace the first" do
      assert calls.first.last.one?(Hash)
    end
  end

  context "A line whose data names a field the handler sets" do
    calls = notifying(:warn, message, { "subject" => "not the class" }, notifier: recorder.new)

    # An item that could be told its subject was something else would file under a class that
    # never logged it.
    test "keeps the handler's own field" do
      assert extra_from(calls).fetch("subject") == subject
    end
  end

  # Rollbar matches a String to the message and an Exception to the exception, and ignores
  # everything else it is handed. Data that is neither reached the item nowhere at all.
  context "A line carrying data that is neither a hash nor an exception" do
    calls = notifying(:warn, message, %w[rec_1 rec_2], notifier: recorder.new)

    test "is named rather than dropped" do
      assert extra_from(calls).fetch("data") == '["rec_1", "rec_2"]'
    end
  end

  context "The line's data is left as the caller passed it" do
    data = { "record_id" => "rec_1" }

    notifying(:warn, message, data, notifier: recorder.new)

    # Rollbar deletes a key from the hash it is given. Handing it a caller's object would
    # mutate something the caller still holds.
    test "is not the hash Rollbar is handed" do
      assert data == { "record_id" => "rec_1" }
    end
  end

  # Hubbado::Log.loggers is config.loggers.map(&:new), so the log system builds every handler
  # itself with no arguments.
  context "Built the way the log system builds it" do
    test "takes none, and notifies Rollbar itself" do
      assert Log::NotifyRollbar.new.notifier.equal?(Rollbar)
    end
  end
end
