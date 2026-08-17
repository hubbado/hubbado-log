module Hubbado
  class Log
    module Controls
      # Stands in for `Rails.logger`, recording the lines it was asked to write.
      #
      # It answers to the severities Rails' own logger answers to, and deliberately not to
      # `trace`, which Rails has no method for. A handler passing the gem's lowest severity
      # straight through raises here exactly as it would in a Rails application, rather than
      # being quietly recorded and passing a spec.
      class RailsLogger
        SEVERITIES = %i[debug info warn error fatal unknown].freeze

        def self.example = new

        def lines = @lines ||= []

        SEVERITIES.each do |severity|
          define_method(severity) { |line| lines << [severity, line] }
        end

        # Without a severity, whether anything was written at all.
        def wrote?(severity = nil)
          return !lines.empty? if severity.nil?

          lines.any? { |written, _| written == severity.to_s.to_sym }
        end

        def reset
          @lines = []
        end

        # The most recent line, as the severity it was written at and the text of it.
        def severity = lines.last&.first

        def line = lines.last&.last
      end
    end
  end
end
