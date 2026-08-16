# StderrLogger Ships With The Gem

Card 6839179, board Metis (194234). Branch `stderr-handler`. This is Part A of two: the gem gains
the handler here, and `metis-hermes-runtime` deletes its four copies once 1.5.0 is released.

## Context

Four projects in `metis-hermes-runtime` — `hubbado-attio`, `hubbado-candidate-query-spec`,
`hubbado-candidate-retrieve` and `hubbado-candidate-score` — each carry a `StderrLogger` that
differs from the others only in its enclosing module name and its file-header comment. `diff`
confirms it: line 5 is the only line that varies. One of the four has three tests; the other three
have none, so a regression printing `nil` for a data-less message, or an inspect string instead of
a backtrace, ships green in three places.

`hubbado-log` deliberately ships no handlers — they live in the application and are built zero-arg
from `config.loggers`. That principle is why a fourth copy was not obviously a defect, and the card
left the destination genuinely open. It is settled now: `eco_core` already ships
`Hubbado::Log::RailsLogger` and `Hubbado::Log::NotifyRollbar` at `lib/hubbado/log/*.rb`, reopening
this gem's namespace, so a handler under `Hubbado::Log::` is the estate's existing shape. The gem
shipping the one handler every CLI wants does not overturn "handlers live in the application" for
the rest — a Rails logger and a Rollbar notifier still belong to their applications, because what
they write to is the application's.

The intended outcome: one stderr handler, its behaviour specced once here rather than
once-in-four-places, released as 1.5.0 so the four copies can be deleted.

## Deliverable

A previously-failing `test/automated/stderr_logger.rb` passing. This is a new class, so it is TDD
throughout — the spec is the work and `lib/hubbado/log/stderr_logger.rb` is what makes it pass.

Baseline before any edit: **96 tests across 8 files, 0 failures** (`ruby test/automated.rb`).

## Task 1: Save spec documentation

Commit `agent-os/specs/2026-08-16-2337-stderr-logger-ships-with-the-gem/` — `plan.md`, `shape.md`,
`standards.md`, `references.md` — before any implementation code.

## Task 2: Make `test/automated/stderr_logger.rb` pass

Write the spec first and watch it fail. Seven behaviours, one `test` each:

1. The line names the severity, the subject and the message.
2. A message with no data prints one line, not a trailing `nil`.
3. An exception prints with its backtrace — the part stderr is worth reading for.
4. An `error` carrying no exception prints the stacktrace the logger synthesised.
5. A `warn` does not print a synthesised stacktrace, so a warn-heavy loop stays readable.
6. An exception's backtrace is not printed twice when a stacktrace arrives alongside it.
7. Built with no arguments it writes to `$stderr`.

1–3 are the three tests `hubbado-attio` already has, brought here. 4–6 are the stacktrace rule,
which is new behaviour and the reason this is not a pure move. 7 is the
`config.loggers.map(&:new)` contract, which nothing tests today in any of the four copies.

The spec calls `log` directly rather than through a `Logger`, so neither the `LOG_LEVEL=_min` nor
the empty `LOG_TAGS` that `test_init.rb` sets can decide what it reads back. It is the first spec
in this repo to capture printed output — every existing handler assertion goes through
`Controls::LogHandler`'s recorded `messages` — and the `io:` keyword is the seam, so no new control
is needed.

Then `lib/hubbado/log/stderr_logger.rb`. The stacktrace prints at `error` and above **and only when
the data is not an Exception**: for an Exception the stacktrace the logger synthesises *is*
`data.full_message`, which the handler already prints, so honouring it there would print the
backtrace twice. The severity set is `Hubbado::Log::STACKTRACE_SEVERITIES` minus `warn` — see
`shape.md` for why `warn` is excluded.

**[TDD-driven]**: the constant's name, whether the stacktrace condition is extracted to a
predicate, how test 7 proves the default, and whether `require_relative '../log'` is the right
dependency for the file to stand alone.

**The file must not be added to `lib/hubbado/log.rb`'s require list.** `require "hubbado/log"`
alone must not define the constant — that is the opt-in contract, and it is the same structural
shape `lib/hubbado/log/controls.rb` already has. The gemspec globs `lib/**/*.rb`, so the file ships
with no gemspec change.

## Task 3: README gains a Handlers section

The README documents no handlers, and its `config.loggers` example at `README.md:56` names an
invented `MyStderrHandler` that has never existed. Add a `## Handlers` section — the class, its
`require`, its `io:` keyword and its stacktrace rule — and repoint the line-56 example at the real
class. It goes after `## A class's own logger`; everything from `## Reading back what a class
logged` (line 144) onward is test-facing.

## Task 4: Release commit — 1.5.0

One commit touching `ChangeLog.md`, `README.md` and `hubbado-log.gemspec`, matching `07a1bc5`
("hubbado-log 1.4.1") in shape. The version lives in the gemspec only; there is no `version.rb`,
and the README's line about one is stale bundler boilerplate. Minor bump: purely additive, nothing
existing changes behaviour.

`ChangeLog.md` gains a `# [1.5.0 - 2026-08-16]` heading with an `## Added` bullet in the file's
house style — prose at ~80 chars, naming that four downstream projects had hand-rolled this and can
delete their copy whenever it suits them.

## Verification

- `ruby test/automated.rb` — 9 files, 96 tests plus the new file's, 0 failures.
- `ruby -e 'require "hubbado/log"; Hubbado::Log::StderrLogger'` raises `NameError`, proving the
  opt-in require is real and not merely intended.
- `gem build hubbado-log.gemspec` lists `lib/hubbado/log/stderr_logger.rb` among its files.

Nothing to verify on a host: this repo is a library and configures no process.

## Out of scope

- **The four copies themselves.** They are deleted in `metis-hermes-runtime` on branch
  `stderr-handler-comes-from-the-gem`, after 1.5.0 is released.
- **`LogContext`**, the helper an unmerged `rollbar-items-group-by-condition` branch adds to three
  projects. That branch is deliberately ignored; this work lands first and it rebases.
- **`eco_core`'s `RailsLogger`.** It could take the same treatment, and it stays where it is.
- **The gemspec's `CHANGELOG*` glob** not matching this repo's `ChangeLog.md` — real, would bite on
  a case-sensitive filesystem, and is not this card's.
