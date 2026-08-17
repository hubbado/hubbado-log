# StderrLogger Ships With The Gem — Shaping Notes

Card 6839179, board Metis (194234).

## Scope

`hubbado-log` gains `Hubbado::Log::StderrLogger`, an opt-in handler that prints a log line where a
person watching a run can see it. Four projects in `metis-hermes-runtime` carry byte-identical
copies of it today, and delete them once 1.5.0 is released.

## The card was half done before it started

Card 6839179 named two hand-copied classes. `Controls::LogHandler` — five copies, the expensive
half at roughly 72 call sites — already left every project under card 6839130 / PR #72, and this
gem shipped the replacement in 1.3.0. What remained was the handler half, which the card explicitly
declined to decide:

> Worth deciding rather than assuming: does a shared `StderrLogger` belong in the gem, in a small
> shared project-level library, or does each project keep its own because the output format is its
> own business?

Two of the card's premises were also wrong on inspection, and are corrected here rather than
carried forward:

- It refers throughout to `hubbado-log` **2.0.0**. There is no 2.0.0. The control shipped in 1.3.0
  and the gem is on 1.4.1.
- It calls the discarded `stacktrace` argument "a defect on its own" in all four copies. It is not
  self-evidently one — see below — though the decision it forces is real.

## Decisions

- **The gem, not a shared project-level library.** `eco_core` already puts its handlers at
  `lib/hubbado/log/rails_logger.rb` and `lib/hubbado/log/notify_rollbar.rb`, reopening this gem's
  namespace. A handler under `Hubbado::Log::` is therefore the estate's existing shape, and the
  alternative — a new shared library in `metis-hermes-runtime` holding fourteen lines — is heavier
  than what it would hold. A project-level library was the other live option and is rejected on
  weight, not on principle.

- **This does not overturn "the gem ships no handlers".** A `RailsLogger` and a `NotifyRollbar`
  still belong to their applications, because what they write to is the application's — a Rails
  logger, a Rollbar token. `$stderr` belongs to nobody, so the handler that writes to it has no
  application to belong to. That is the line, and it admits exactly one handler.

- **Named `StderrLogger`, not `StderrHandler`.** `StderrHandler` reads better against the
  `LogHandler` base class, but the estate already says `RailsLogger` and `NotifyRollbar`, and
  `Hubbado::Log::RailsLogger` has coexisted with `Hubbado::Log::Logger` in `eco_core` without
  confusing anybody. Consistency with the two handlers that exist beats consistency with the base
  class they inherit from. It also makes the downstream change a one-token module swap.

- **The stacktrace prints at `error` and above, not at `warn`.** This is the one contested call.
  Against printing it: `$stderr` is a person watching a run, and the gem synthesises
  `Kernel.caller` for `warn` as well (`lib/hubbado/log/logger.rb:45-49`), so honouring it
  unconditionally puts roughly thirty lines of Ruby stack under every warning — in `hubbado-attio`'s
  card-sweep loop that is the log made unreadable to fix a triage problem stderr does not have.
  For printing it: `eco_core`'s `RailsLogger:6` does `Rails.logger.send(severity, stacktrace) if
  stacktrace`, so a handler in this estate already honours the argument, and the four metis copies
  are the outliers rather than the norm.

  The split resolves it. An `error` is a failure somebody has to find; a `warn` is a condition
  somebody should look at eventually, and the message already names the field and value. So: print
  at `error`, `fatal` and `unknown`; stay quiet at `warn`. That is
  `Hubbado::Log::STACKTRACE_SEVERITIES` minus `warn`.

- **Never print the stacktrace for an Exception.** When `data` is an Exception the logger sets
  `stacktrace` to `data.full_message` — the identical string the handler already prints from `data`
  itself. Honouring the argument there would print the backtrace twice. This is why the condition
  is not simply `if stacktrace`, and it is the part a reader is most likely to try to simplify
  away, so it gets a test of its own (behaviour 6).

- **Opt-in require, structurally rather than by assertion.** `lib/hubbado/log.rb` does not require
  the file, exactly as it does not require `lib/hubbado/log/controls.rb`. There is no spec asserting
  `Controls` stays unloaded either; a spec that has already loaded the gem cannot un-load it, and
  shelling out a subprocess to prove a require list is heavier than the fact is worth. The
  verification step covers it with a one-line `ruby -e` instead.

## Why this is TDD and the downstream half is not

A new class with new behaviour has a failing spec available, so it gets one. Three of the seven
behaviours are the tests `hubbado-attio` already had; the four new ones are the stacktrace rule and
the zero-argument construction contract. That contract is worth naming: `config.loggers.map(&:new)`
builds every handler with no arguments (`lib/hubbado/log/log.rb:28`), so a handler whose
`initialize` grew a required argument would fail at process start and nothing in any of the four
copies would have caught it.

Part B in `metis-hermes-runtime` is a deletion, so its deliverable is the five suites staying green
at their baseline counts, not a new spec.

## This is the first spec here to capture output

Every handler assertion in this repo goes through `Controls::LogHandler`'s recorded `messages`
array; `$stderr`, `STDOUT` and `StringIO` appear nowhere in `lib/` or `test/`. The `io:` keyword is
the seam and needs no new control — a `StringIO` passed in is enough. Worth knowing that
`test/test_init.rb:1` sets `CONSOLE_DEVICE=stdout`, steering TestBench's own output away from
stderr, so a test that does exercise the real default cannot be confused with the runner's noise.

## Context

- **Visuals:** None. No user-facing surface.
- **References:** `eco_core`'s two handlers, the four copies being replaced, and this repo's own
  `controls.rb` as the opt-in-require precedent — see `references.md`.
- **Product alignment:** N/A. Neither this repo nor `metis-hermes-runtime` has `agent-os/product/`.

## Standards Applied

`hubbado-log` has no `agent-os/standards/` of its own; these come from `metis-hermes-runtime` — see
`standards.md`.

- `global/conventions.md` — the logging run: what each severity means, that an exception is passed
  as data rather than interpolated, and that `warn`/`error`/`fatal` reach Rollbar. The severity
  definitions are what decide where the stacktrace line is drawn.
- `global/code-organization.md` — explicit require chains; the new file requires what it needs so
  the opt-in require stands alone.
- `testing/test-writing.md` — behaviour-per-file layout, one behaviour per `test`.
