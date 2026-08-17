module Hubbado
  class Log
    module Controls
      # Stands in for the Rollbar module, recording what it was handed rather than sending it.
      # Every level Rollbar answers to is defined, so a handler notifying at a level it should
      # have stayed quiet at is recorded and asserted against rather than raising.
      class Rollbar
        # Rollbar takes its arguments positionally and untyped, scanning them for a String, an
        # Exception and a Hash. Reading them back the same way is the point of this control: a
        # notification is asserted on for what Rollbar would make of it, not for the order a
        # handler happened to pass things in.
        Notification = Struct.new(:level, :arguments) do
          def message = arguments.find { |argument| argument.is_a?(String) }

          # `::Exception`, not `Exception` — this module has a control of that name, and a bare
          # constant here resolves to it and matches nothing.
          def exception = arguments.find { |argument| argument.is_a?(::Exception) }

          # The **last** hash, discarding any earlier one, because that is what Rollbar does.
          # A handler passing two would read as correct against a control that merged them, and
          # lose a hash against the real thing.
          def extra = arguments.grep(Hash).last

          def hashes = arguments.grep(Hash).length
        end

        LEVELS = %i[debug info warning warn error critical].freeze

        def self.example = new

        def notifications = @notifications ||= []

        LEVELS.each do |level|
          define_method(level) { |*arguments| notifications << Notification.new(level, arguments) }
        end

        # Without a level, whether anything was sent at all — which a spec asserting silence
        # would otherwise have to infer from an attribute never having been set.
        def notified?(level = nil)
          return !notifications.empty? if level.nil?

          notifications.any? { |notification| notification.level == level.to_s.to_sym }
        end

        def reset
          @notifications = []
        end

        # The most recent notification. Derived rather than assigned alongside `notifications`,
        # so the two cannot disagree about which is the latest.
        %i[level message exception extra].each do |field|
          define_method(field) { notifications.last&.public_send(field) }
        end
      end
    end
  end
end
