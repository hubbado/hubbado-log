# References for StderrLogger Ships With The Gem

## The prior art that decided the destination

### `Hubbado::Log::RailsLogger`

- **Location:** `hubbado/eco_core/lib/hubbado/log/rails_logger.rb`
- **Relevance:** This is why the handler belongs in this gem's namespace. `eco_core` already puts
  its handlers at `lib/hubbado/log/*.rb`, reopening `class Hubbado::Log` — so
  `Hubbado::Log::StderrLogger` is not a new idea, it is the shape the estate already uses.
- **Whole file:**

      class Hubbado::Log
        class RailsLogger < LogHandler
          def log(subject, severity, msg, data = nil, stacktrace = nil)
            Rails.logger.send(severity, "#{subject}: #{msg}")
            Rails.logger.send(severity, data.inspect) if data
            Rails.logger.send(severity, stacktrace) if stacktrace
          end
        end
      end

- **Key pattern:** line 6 honours the fifth argument unconditionally. That is the counter-example to
  "discarding the stacktrace is fine" and the reason the new handler prints one at all. It is
  followed on the question of *whether*, and deliberately not on *when* — a Rails log is read after
  the fact by a machine, a terminal is read live by a person.

### `Hubbado::Log::NotifyRollbar`

- **Location:** `hubbado/eco_core/lib/hubbado/log/notify_rollbar.rb`, and a separate
  implementation at
  `metis-hermes-runtime/projects/hubbado-attio/lib/hubbado_attio/notify_rollbar.rb`
- **Relevance:** The second handler under this gem's namespace, confirming the pattern is not a
  one-off. Also the counter-example that keeps the "no handlers in the gem" principle intact — it
  needs a Rollbar token and an environment, which are the application's, so it stays in the
  application.

## The copies being replaced

Four files, one per project, in `metis-hermes-runtime`:

| Project | File | Spec |
|---|---|---|
| `hubbado-attio` | `lib/hubbado_attio/stderr_logger.rb` | `test/automated/stderr_logger.rb`, 3 tests |
| `hubbado-candidate-query-spec` | `lib/hubbado_candidate_query_spec/stderr_logger.rb` | none |
| `hubbado-candidate-retrieve` | `lib/hubbado_candidate_retrieve/stderr_logger.rb` | none |
| `hubbado-candidate-score` | `lib/hubbado_candidate_score/stderr_logger.rb` | none |

`diff` across the four reports **line 5 as the only difference** — the enclosing `module` name. The
file-header comments read differently per project but sit above the class, not in the body. The
shared body:

    class StderrLogger < Hubbado::Log::LogHandler
      def initialize(io: $stderr)
        @io = io
      end

      def log(subject, severity, message, data = nil, _stacktrace = nil)
        io.puts("#{severity.to_s.upcase} #{subject}: #{message}")
        io.puts(data.is_a?(Exception) ? data.full_message : data.inspect) unless data.nil?
      end

      private

      attr_reader :io
    end

`hubbado-teamxchange-scrape` is the fifth project in that repo and has no `StderrLogger` at all.

### The three tests being brought here

`metis-hermes-runtime/projects/hubbado-attio/test/automated/stderr_logger.rb` — the only spec any
of the four has. Its three cases become behaviours 1–3, with its `def self.logged` helper shape
kept: build a `StringIO`, hand it in as `io:`, call `log`, read `io.string`.

## Where the stacktrace argument comes from

- **Location:** `lib/hubbado/log/logger.rb:45-49`
- **Relevance:** This is what decides what the handler receives, and reading it is what settled the
  Exception case.

      stacktrace = if data.is_a?(Exception)
                     data.full_message
                   elsif STACKTRACE_SEVERITIES.include?(severity)
                     format_stacktrace Kernel.caller
                   end

  For an Exception the argument is `data.full_message` — the same string the handler prints from
  `data` itself, hence the no-double-printing rule. Otherwise it is the caller stack, synthesised
  for every severity in `STACKTRACE_SEVERITIES`.

- **`Hubbado::Log::STACKTRACE_SEVERITIES`** — `lib/hubbado/log/log.rb:9`,
  `%i[warn error fatal unknown].freeze`. The new handler's set is this minus `warn`.
- **`Hubbado::Log::LogHandler`** — `lib/hubbado/log/log_handler.rb:4`, the five-argument contract
  the new class implements.
- **`Hubbado::Log.loggers`** — `lib/hubbado/log/log.rb:28`, `config.loggers.map(&:new)`. The
  zero-argument construction contract behaviour 7 exists for.

## The opt-in require precedent

- **Location:** `lib/hubbado/log/controls.rb`
- **Relevance:** The existing answer to "a thing you require separately". It is a file of nothing
  but `require_relative` lines, and it is absent from `lib/hubbado/log.rb`'s require list, so
  consumers write `require 'hubbado/log/controls'` themselves (`test/test_init.rb:16`). The new
  handler takes the same shape: a file under `lib/hubbado/log/` that `log.rb` does not name.
- **Note:** there is no spec asserting `Controls` stays unloaded, which is why the new file does not
  get one either.

## Repo conventions worth not re-deriving

- **No `# frozen_string_literal: true` anywhere** — `hubbado-style`'s `default.yml:50-51` disables
  `Style/FrozenStringLiteralComment`. The four copies being replaced all carry one; the gem's
  version must not.
- **No file-header comments** — comments sit above classes, methods and constants, never at file
  top. `lib/hubbado/log/tags.rb` is the density to match.
- **Nesting is always explicit** — `module Hubbado` / `class Log` / `class X`, never the compact
  `class Hubbado::Log::X`. Note `Log` is a class, not a module.
- **Spec files** open with `require_relative 'automated_init'`, then a top-level `context`. Helpers
  are `def self.name` inside the context. `test/test_init.rb` does `include Hubbado` at top level,
  so specs address the constant as `Log::StderrLogger`.
- **`test/automated.rb`** globs `test/automated`, excluding `{_*,*sketch*,*_init,*_tests}.rb`, so a
  new file is picked up with no registration.
- **Release** is one hand-made commit over `ChangeLog.md`, `README.md` and the gemspec — see
  `07a1bc5`. There is no Rakefile, no release script and no publish workflow;
  `.github/workflows/ci.yml` only runs the suite.

## Related cards and branches

- **Card 6839130 / PR #72** — took `Controls::LogHandler` from the gem across five projects. Done.
  The other half of card 6839179, and the reason only the handler remains.
- **Card 6839114 / PR #7** — added the control to the gem in 1.3.0.
- **`metis-hermes-runtime` branch `rollbar-items-group-by-condition`** — unmerged, rewrites all four
  copies, adds stderr specs to three projects, and adds a `LogContext` module hand-copied into
  three. Deliberately ignored: this work lands first and that branch rebases onto it.
