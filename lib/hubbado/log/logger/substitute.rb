module Hubbado
  class Log
    class Logger
      # What a logger was told rather than what it wrote. Extended onto a mimic of Logger, so a
      # class under test is handed something that answers as a logger and keeps what it was given.
      module Substitute
        # One line, as the logger read it rather than as the call site typed it.
        Entry = Data.define(:severity, :message, :data, :tags) do
          # Compared as a symbol, because #log takes a String as readily and passes on what it
          # was given.
          def at?(name) = severity == name.to_s.to_sym

          # A String names the line in full. A Regexp names enough of it to tell it from the
          # others, which is what a spec wants when the line carries a record id it does not
          # care about.
          def says?(pattern)
            return pattern.match?(message.to_s) if pattern.is_a?(Regexp)

            message == pattern
          end

          # Every tag the line carries, and no others. Order is not compared: a call site writes
          # them in whatever order reads well, and the allow-list never sees one either.
          def tagged?(names) = tags.uniq.sort == names.uniq.sort
        end

        # Everything about what a class said, in order, narrowed by whichever criteria a spec
        # names. Asked together rather than one at a time: a run writes several lines, and a
        # message and a tag list asserted apart can each be true of a different one.
        def logged(severity = nil, message: nil, tags: nil)
          entries = invocations.map { |invocation| entry(invocation) }

          entries = entries.select { |entry| entry.at?(severity) } unless severity.nil?
          entries = entries.select { |entry| entry.says?(message) } unless message.nil?
          entries = entries.select { |entry| entry.tagged?(symbols(tags)) } unless tags.nil?

          entries
        end

        # What a class said, where #logged is everything about it.
        def messages(...) = logged(...).map(&:message)

        # Whether, where #logged and #messages ask what. Without anything named, whether anything
        # was written at all.
        def logged?(...) = !logged(...).empty?

        private

        # A severity reaches a logger two ways: as the method, from the generated severity methods,
        # or as #log's first argument, which takes a String as readily and passes on what it was
        # given. Both tags keywords are kept in one list, as the logger keeps them, so a spec does
        # not break when a call site is rewritten from the singular to the plural.
        def entry(invocation)
          arguments = invocation.arguments

          severity = arguments.fetch(:severity, invocation.method_name)

          Entry.new(
            severity: severity.to_s.to_sym,
            message: arguments[:msg],
            data: arguments[:data],
            tags: symbols(arguments[:tags]) + symbols(arguments[:tag])
          )
        end

        # One name or a list of them, however a call site or a spec wrote it.
        def symbols(names) = Array(names).map { |name| name.to_s.to_sym }
      end
    end
  end
end
