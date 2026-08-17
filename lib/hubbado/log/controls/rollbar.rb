module Hubbado
  class Log
    module Controls
      # Stands in for the Rollbar module, recording what it was handed rather than sending it.
      # Every level Rollbar answers to is defined, so a handler notifying at a level it should
      # have stayed quiet at is recorded and asserted against rather than raising.
      class Rollbar
        # Rollbar takes its arguments positionally and untyped, assigning each one it recognises
        # over any earlier one of the same kind. So every reader here takes the **last** match,
        # not the first: a notification is asserted on for what Rollbar would make of it, and a
        # handler passing two of anything must lose the same one here that it loses there.
        Notification = Struct.new(:level, :arguments) do
          def message = arguments.grep(String).last

          # `::Exception`, not `Exception` — this module has a control of that name, and a bare
          # constant here resolves to it and matches nothing.
          def exception = arguments.grep(::Exception).last

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

        # The most recent notification. Derived rather than assigned alongside `notifications`,
        # so the two cannot disagree about which is the latest.
        %i[level message exception extra].each do |field|
          define_method(field) { notifications.last&.public_send(field) }
        end
      end
    end
  end
end
