require_relative 'automated_init'

require 'hubbado/log/notify_rollbar'

# What reaches Rollbar, and what a person triaging an item is given to work with.
context "NotifyRollbar" do
  subject = Log::Controls::Subject.example
  message = Log::Controls::Message.example

  stacktrace = Log::Controls::Stacktrace.example

  def self.notifying(severity, msg, data = nil, stacktrace = nil)
    notifier = Log::Controls::Rollbar.example

    Log::NotifyRollbar.new(notifier: notifier)
      .log(Log::Controls::Subject.example, severity, msg, data, stacktrace)

    notifier
  end

  context "Severities Rollbar has a level for" do
    context "a warning" do
      notifier = notifying(:warn, message)

      test "reaches Rollbar as a warning, not as an error" do
        assert notifier.level == :warn
      end
    end

    # Rollbar has no level above error, so the two severities above warn share it.
    %i[error fatal unknown].each do |severity|
      context severity.to_s do
        notifier = notifying(severity, message)

        test "reaches Rollbar as an error" do
          assert notifier.level == :error
        end
      end
    end
  end

  context "Severities below a warning" do
    notifier = notifying(:info, message)

    test "are running commentary, and are not incidents" do
      refute notifier.notified?
    end
  end

  context "The line itself" do
    notifier = notifying(:warn, message)

    test "carries the message" do
      assert notifier.message == message
    end

    # Rollbar groups on the message, so an item that does not say which class wrote it groups
    # every class sharing a wording into one incident.
    test "names the class that logged it" do
      assert notifier.extra.fetch("subject") == subject
    end
  end

  context "A line carrying an exception" do
    exception = Log::Controls::Exception.example

    notifier = notifying(:error, message, exception, exception.full_message)

    test "hands Rollbar the exception itself, which is what it groups and traces on" do
      assert notifier.exception.equal?(exception)
    end

    # Rollbar reads the backtrace off the exception. Sending it again as data would put the
    # same frames in the item twice.
    test "does not also send the stacktrace as data" do
      refute notifier.extra.key?("stacktrace")
    end
  end

  context "An error carrying no exception" do
    notifier = notifying(:error, message, nil, stacktrace)

    test "sends the stacktrace the logger synthesised, which is all the item has" do
      assert notifier.extra.fetch("stacktrace") == stacktrace
    end
  end

  # Rollbar keeps the last hash it is handed and discards any earlier one, so the line's own
  # data and the handler's fields have to arrive as one.
  context "A line carrying a hash" do
    notifier = notifying(:warn, message, { "record_id" => "rec_1" })

    test "reaches the item rather than being displaced by the handler's own fields" do
      assert notifier.extra.fetch("record_id") == "rec_1"
      assert notifier.extra.fetch("subject") == subject
    end

    test "arrives as a single hash, because a second one would replace the first" do
      assert notifier.notifications.last.hashes == 1
    end
  end

  context "A line whose data names a field the handler sets" do
    notifier = notifying(:warn, message, { "subject" => "not the class" })

    # An item that could be told its subject was something else would file under a class that
    # never logged it.
    test "keeps the handler's own field" do
      assert notifier.extra.fetch("subject") == subject
    end
  end

  # Rollbar matches a String to the message and an Exception to the exception, and ignores
  # everything else it is handed. Data that is neither reached the item nowhere at all.
  context "A line carrying data that is neither a hash nor an exception" do
    notifier = notifying(:warn, message, %w[rec_1 rec_2])

    test "is named rather than dropped" do
      assert notifier.extra.fetch("data") == '["rec_1", "rec_2"]'
    end
  end

  # Rollbar matches its title by type, so a message that is not a String is ignored and the item
  # arrives with no title at all — nothing for a person to read in the incident list.
  context "A message that is not a string" do
    notifier = notifying(:warn, :card_skipped)

    test "still titles the item" do
      assert notifier.message == "card_skipped"
    end
  end

  context "The line's data is left as the caller passed it" do
    data = { "record_id" => "rec_1" }

    notifying(:warn, message, data)

    # Rollbar deletes a key from the hash it is given. Handing it a caller's object would
    # mutate something the caller still holds.
    test "is not the hash Rollbar is handed" do
      assert data == { "record_id" => "rec_1" }
    end
  end

  # Rollbar is a real loaded module here, so reading the default means standing a control in its
  # place rather than sending anything. Restored in an ensure: every spec file in a run shares
  # one process, so a swapped ::Rollbar left behind would be the one they all see.
  def self.with_rollbar(notifier)
    real = Rollbar

    Object.send(:remove_const, :Rollbar)
    Object.const_set(:Rollbar, notifier)

    yield
  ensure
    Object.send(:remove_const, :Rollbar)
    Object.const_set(:Rollbar, real)
  end

  # Hubbado::Log.loggers is config.loggers.map(&:new), so the log system builds every handler
  # itself with no arguments.
  context "Built the way the log system builds it" do
    notifier = Log::Controls::Rollbar.example

    with_rollbar(notifier) do
      Log::NotifyRollbar.new.log(subject, :error, message)
    end

    test "takes none, and notifies Rollbar itself" do
      assert notifier.level == :error
      assert notifier.message == message
    end
  end
end
