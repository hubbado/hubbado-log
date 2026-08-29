# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

# [2.0.0 - 2026-08-29]
## Fixed
- `LOG_TAGS` and `LOG_LEVEL` no longer decide whether a failure is reported.
  Both were applied in `Logger`, above the handler fan-out, so an operator
  narrowing the log to the step they were debugging, or raising the level to cut
  what an unattended log costs to keep, also stopped `NotifyRollbar` filing the
  incident. A crash in any other step went unreported.

  `StderrLogger` and `RailsLogger` now ask `Display` for themselves before
  writing. `NotifyRollbar` does not ask, so it is reached whatever the settings
  say, and declines anything below `warn` on its own as before.

- A failure written with a String severity is given a stacktrace, as one written
  with a symbol always was. `#log` validates the severity as a symbol but
  compared it raw when deciding whether to synthesise a caller stack, so
  `Hubbado::Log.log('error', msg)` was accepted, logged, and arrived with no
  stack under it.

  Latent until now — every call site across Hubbado names its severity as a
  symbol — and worth fixing here because such a message could previously be
  filtered away entirely. Now that every warning and error reaches Rollbar, it
  would instead be filed as an item nobody can act on.

## Added
- `Hubbado::Log::Display`, which answers whether the operator asked to be shown
  a message. A handler that writes where a person reads asks it; one that
  reports an incident does not.

  ```ruby
  class MyHandler < Hubbado::Log::LogHandler
    def log(subject, severity, message, data = nil, stacktrace = nil, tags = [])
      return unless Hubbado::Log::Display.shows?(severity, tags)

      ...
    end
  end
  ```

  A printing handler that forgets to ask prints everything, whatever the
  operator set.


- The logger substitute names a line by its message and its tags, not only by
  its severity. `logged?`, `messages` and `logged` all take the same criteria.

  ```ruby
  assert logger.logged?(:info, message: /handed back/, tags: %i[rescoring sweep])
  ```

  Named together rather than one at a time, because a run writes several lines
  and a message and a tag list asserted apart can each be true of a different
  one. Before this, a spec asking about a line's tags reached past the
  substitute into `invocations.first.arguments.fetch(:tag)` — which bound the
  assertion to which keyword the call site happened to use, so rewriting
  `tag: :claim` to `tags: [:claim]` broke a spec without changing any behaviour.

  `message:` matches a String in full or a Regexp in part. `tags:` takes one
  symbol or a list, reads both keywords as the logger does, and names every tag
  the line carries and no others, in any order.

  Entries answered by `logged` carry `tags` alongside `severity`, `message` and
  `data`.

## Breaking
- **`LOG_LEVEL` and `LOG_TAGS` no longer hold Rollbar volume down.** That is the
  point of the fix above, and it is a change to what an operator can do: a
  process running `LOG_LEVEL=error`, or a narrowed list, to keep the incident
  count low loses that lever on upgrade. Every `warn` and above now files,
  whatever the settings say, and `NotifyRollbar`'s own `warn` floor is the only
  one left. Rollbar's own rate limiting is where volume is held now.
- **`LogHandler#log` takes a sixth argument**, the tags the message was written
  with, as symbols. A handler defining five parameters raises when called — and
  raises from inside the logging call, so it takes down the operation being
  logged rather than only the log line. A keyword with a default would not have
  softened this: Ruby folds a trailing hash into a sixth positional for a method
  that declares no keywords, and it raises identically.
- **The per-logger `level:` and `tags:` overrides are gone.** `Logger.new` takes
  a subject and its handlers, and nothing else; a handler reads the process's
  configuration. Nothing across Hubbado set either — only this gem's own
  controls did. This is a deliberate divergence from Eventide's log gem, which
  keeps that seam: restoring it would mean putting the effective level and list
  back onto the handler contract that this release widened.
- **`Controls::LogHandler.attach` and `.logger` no longer take `level:` or
  `tags:`.** The control records rather than displays, so nothing filters what a
  spec attaching one can read.

## Changed
- A message tagged `:*` now means only "display this whatever the list says",
  which is what it means in Eventide's log gem. It is no longer what keeps an
  incident alive, because nothing can silence one.

# [1.5.0 - 2026-08-16]
## Added
- Three handlers, replacing eight hand-rolled copies across four projects and
  two applications. Each is behind its own require; `require "hubbado/log"`
  loads none of them.

  ```ruby
  require "hubbado/log/stderr_logger"
  require "hubbado/log/notify_rollbar"

  Hubbado::Log.configuration do |config|
    config.loggers = [Hubbado::Log::StderrLogger, Hubbado::Log::NotifyRollbar]
  end
  ```

  | Handler | Writes to | Needs |
  |---|---|---|
  | `StderrLogger` | `$stderr` | nothing |
  | `RailsLogger` | `Rails.logger` | Rails, already loaded wherever a handler is registered |
  | `NotifyRollbar` | `Rollbar` | `rollbar` in the consumer's own Gemfile |

  Neither Rails nor Rollbar is a dependency of this gem, so installing it
  installs neither. `notify_rollbar` requires `rollbar` at the top of the file,
  making an absent gem a `LoadError` at boot rather than a `NameError` raised
  while a failure is being reported.

  Every copy discarded the `stacktrace` argument, and the Rollbar ones
  discarded more:

  | | Was | Is now |
  |---|---|---|
  | `StderrLogger`, an `error` carrying no exception | no stacktrace | prints it. A `warn` stays one line, and an exception's backtrace is never printed twice |
  | `RailsLogger`, a `trace` line | `NoMethodError` in one of the two copies | written as `debug` |
  | `NotifyRollbar`, the subject | dropped | a `subject` key, merged last so a line cannot claim another class |
  | `NotifyRollbar`, a stacktrace with no exception | dropped | a `stacktrace` key |
  | `NotifyRollbar`, data that is not a hash or exception | dropped | a `data` key holding its `inspect` |

  Rollbar keeps the last hash it is handed and ignores anything that is not a
  String, an Exception or a Hash, so `NotifyRollbar` merges everything into one
  hash — built fresh per call, because Rollbar deletes a key from the hash it
  is given.

- Controls for what a handler spec stands in for: `Controls::Rollbar`,
  `Controls::RailsLogger`, `Controls::Receiver` and `Controls::Stacktrace`.

  `Controls::Rollbar` reads a notification back the way Rollbar reads its
  arguments, keeping the last hash — so a handler sending two would pass
  against a merging control and lose data against the real thing.
  `Controls::RailsLogger` does not answer to `trace`, so a handler passing it
  straight through raises here as it would in Rails.

# [1.4.1 - 2026-08-16]
## Fixed
- A subclass of `Hubbado::Log` can be used as a dependency. It answered `nil`
  from `config` and raised `undefined method 'loggers' for nil` on its first
  line, because the configuration was held in a class-level instance variable
  and those are not inherited.

  ```ruby
  module Messaging
    class Log < Hubbado::Log; end
  end

  class Handler
    include Messaging::Log::Dependency
  end
  ```

  The configuration is the process's now, and holds the handlers built from it,
  so every class that writes reads the one a command configured and one
  reconfiguration reaches all of them.

# [1.4.0 - 2026-08-16]
## Added
- A substitute for a logger. `Controls::Logger.example` returns one, and a spec
  assigns it where a class's logger goes:

  ```ruby
  instance.logger = Hubbado::Log::Controls::Logger.example

  instance.()

  assert instance.logger.logged?(:error)
  ```

  It records what it was told rather than writing, so no handler is involved and
  neither the level nor the tag list decides what a spec can read back.

  Three questions, each taking an optional severity, and each answering in the
  terms its name promises:

  | Call | Answers |
  |---|---|
  | `logged?(:warn)` | whether anything was written at that severity |
  | `messages(:warn)` | what it said — the message strings |
  | `logged(:warn)` | everything about what it said — `severity`, `message`, `data` |

  `messages` and `logged?` are both derived from `logged`, so the three cannot
  disagree about what counts as written at a severity.

  A severity reaches a logger two ways — as the generated method, or as `#log`'s
  first argument — and both answer the same question, compared as symbols.

- `evt-subst_attr` as a runtime dependency. The substitute is a mimic of `Logger`
  extended with `Logger::Substitute`, so it answers `is_a?(Logger)` for a class
  that checks, and gains any method `Logger` gains.

## Deprecated
- `Controls::LogHandler` as the way a consumer reads back what a class logged.
  It builds a real `Logger` and then passes `level: :trace` and `tags: Tags::ALL`
  to switch off the filtering it just built — which is a substitute, reached the
  long way round. Use `Controls::Logger.example`. The handler control stays for
  what it is good at: specs where a handler receiving, or not receiving, a
  message is the subject, as `'A message the filter left out'` is.

## Changed
- `Controls::LogHandler` names `Log::Logger` where it said `Logger`. With
  `Controls::Logger` defined, a bare `Logger` inside `Controls` resolves to the
  control rather than to the class.

## Compatibility
Nothing that exists breaks. `Controls::LogHandler` keeps `.attach`, `.logger`,
`messages`, `logged?`, `reset` and the attributes, unchanged.

# [1.3.0 - 2026-08-15]
## Added
- Tags, a second filtering axis beside the level. A message names its concern
  with `tag:` or `tags:`, and `LOG_TAGS` decides which tagged messages are
  written. The syntax and semantics are Eventide's log gem's, so a string an
  operator writes means the same thing in both codebases.
- `config.tags`, set in code the way `config.level` is, and a `tags:` keyword on
  `Logger.new` so one logger can name its own list without the process being
  turned up around it — the escape hatch the level already had.
- `Controls::LogHandler` records every message it is given in `messages`, answers
  `logged?` with or without a severity, resets with `reset`, and builds a wired
  logger with `.attach` or `.logger`. Five downstream projects had each
  hand-rolled the same thing because the control kept only the most recent; they
  can delete their copy whenever it suits them. The attributes still read the
  most recent, derived from `messages` rather than assigned beside it.
- `.attach` and `.logger` name `_all` as well as `trace`, so neither the
  configured level nor the configured tag list decides what a spec can read back.
  `.attach` raises a named `ArgumentError` for a class carrying no logger rather
  than failing on nil.

## Changed
- The test suite sets `LOG_TAGS` rather than defaulting it, so a value left in a
  developer's shell cannot decide which tests can write anything.

## Compatibility
Nothing that exists breaks. A handler's arguments are unchanged — tags decide
whether it is called, and are not passed to it. Every handler across the
consuming repositories was checked and needs no edit.

One theoretical change: the severity methods and `Hubbado::Log.log` now name
`tag:` and `tags:`, so a call site passing its data as bare keywords —
`logger.info('x', record_id: 7)`, which worked because Ruby folded them into a
positional hash while the methods accepted none — raises instead. No such call
site exists in any consuming repository; pass the hash explicitly if one appears.

## Not included
A tag declared once per component, and tags reaching a log handler. Neither has
an implementer: nothing tags a message yet, and no handler prints or routes on
one. Eventide does not pass tags to its own output either — they filter, and
stop there. Both are worth adding when something needs them, and neither has to
break a handler to arrive.

# [1.2.0 - 2026-08-14]
## Added
- A `trace` level, below `debug`. Program flow — a line per iteration of a loop —
  so that turning on the completion of secondary operations does not also turn on
  a line per item in a set.

# [1.1.0 - 2026-08-14]
## Added
- A level, below which a line reaches no handler. Set it with `config.level`, or
  with the `LOG_LEVEL` environment variable, which defaults to `info` — so
  `debug` is off unless it is asked for.

## Changed
- `Logger.new` takes a `level:` keyword. A logger built without one follows the
  configuration.
- `LOG_LEVEL` is shared with Eventide's log gem, which writes names this gem does
  not know. A name that is not a severity leaves the level at `info` rather than
  raising.

# [1.0.1 - 2024-05-30]
# Changed
- Release to stop a SHA mismatch between our private github package repo and Ruby Gems

# [1.0.0 - 2024-05-02]
## Added
- Dependency module for easier setup
- Changed from RSpec to TestBench
- Add "subject" to record where the logger is invoked (defaults to the class
  name when configured via Dependency)

# [0.2.1 - 2021-04-27]
## Changed
- Use github packages as gem source for our own gems
