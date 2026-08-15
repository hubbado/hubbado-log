module Hubbado
  class Log
    # The operator's list, from LOG_TAGS: an allow-list a message's own tags have to intersect
    # before it is written.
    class Tags
      # Every tag is written, whatever else the list says.
      ALL = :_all

      # Messages carrying no tag at all are written. Without it, naming any tag silences them.
      UNTAGGED = :_untagged

      # A message marks itself as written whatever the operator asked for.
      EVERY_MESSAGE = :*

      EXCLUSION = "-".freeze

      # Split on commas and nothing else, which is all Eventide's log gem does. Trimming the
      # spaces would be kinder, and would make one LOG_TAGS mean different things in the two gems
      # that share the variable — the divergence this gem cannot afford.
      def self.parse(value)
        return value if value.is_a?(self)
        return new if value.nil?
        return new(value) if value.is_a?(Array)

        new(value.to_s.split(","))
      end

      attr_reader :tags

      def initialize(tags = [])
        @tags = Array(tags).map { |tag| tag.to_s.to_sym }
      end

      # An exclusion-only list still counts as the operator having named tags, which is what
      # makes `-data` on its own silence everything rather than subtract from everything.
      def any?
        !tags.empty?
      end

      # Branch for branch from Eventide's log gem, so that a string an operator writes means the
      # same thing in both codebases. That includes the awkward part: `_all` is answered before
      # any exclusion, so `_all,-data` writes `data` messages regardless.
      def write?(message_tags)
        message_tags = Array(message_tags)

        return true if message_tags.empty? && !any?
        return true if message_tags.include?(EVERY_MESSAGE)
        return true if named?(ALL)
        return true if message_tags.empty? && named?(UNTAGGED)
        return true if !message_tags.empty? && any? && intersect?(message_tags)

        false
      end

      private

      def named?(tag)
        tags.include?(tag)
      end

      def intersect?(message_tags)
        return false if message_tags.intersect?(excluded)

        included.intersect?(message_tags)
      end

      def included
        @included ||= tags.reject { |tag| excluded?(tag) }
      end

      def excluded
        @excluded ||= tags
          .select { |tag| excluded?(tag) }
          .map { |tag| tag.to_s.delete_prefix(EXCLUSION).to_sym }
      end

      def excluded?(tag)
        tag.to_s.start_with?(EXCLUSION)
      end
    end
  end
end
