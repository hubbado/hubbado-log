# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

# [1.5.0 - 2026-08-16]
## Added
- A stderr handler, which four downstream projects had each hand-rolled. The
  copies differed only in the module name around them, and three of the four
  had no spec at all, so a regression printing `nil` for a data-less message
  shipped green in three places. They can delete their copy whenever it suits
  them.

  ```ruby
  require "hubbado/log/stderr_logger"

  Hubbado::Log.configuration do |config|
    config.loggers = [Hubbado::Log::StderrLogger]
  end
  ```

  It is not required by `hubbado/log`. Which handlers exist is the process's to
  decide, and a consumer asks for this one the same way it already asks for
  `hubbado/log/controls`.

  This gem otherwise ships no handlers, because what a handler writes to is the
  application's — a Rails logger, a Rollbar token. `$stderr` is owned by nobody,
  so this is the one handler with no application to belong to.

  It also stops discarding the stacktrace, which every copy did. A stacktrace
  prints at `error` and above, and only when the data is not an exception: for
  an exception the stacktrace is that exception's own `full_message`, already
  printed from the data, so honouring both would print the backtrace twice. A
  `warn` stays one line — it is a condition to examine rather than a failure to
  trace, and a sweep that warns per row would otherwise bury itself in Ruby
  stack.

- A Rollbar handler, which two Rails applications had hand-rolled identically.

  ```ruby
  require "hubbado/log/notify_rollbar"

  Hubbado::Log.configuration do |config|
    config.loggers = [Hubbado::Log::StderrLogger, Hubbado::Log::NotifyRollbar]
  end
  ```

  **Rollbar is not a dependency of this gem**, and installing `hubbado-log`
  does not install it. It is a development dependency, needed only to run this
  gem's own tests. A consumer that wants the handler puts `rollbar` in its own
  Gemfile; the handler's `require` raises `LoadError` at boot if it is absent,
  rather than a `NameError` inside `log` at the moment a failure is being
  reported.

  Three things the copies got wrong, all from the same cause. Rollbar scans its
  arguments by type, keeps the **last** hash it is handed, and ignores anything
  that is not a String, an Exception or a Hash:

  | The line has | Was | Is now |
  |---|---|---|
  | a subject | dropped | a `subject` key, merged last so a line cannot claim another class |
  | a stacktrace, no exception | dropped | a `stacktrace` key |
  | data that is not a hash or exception | dropped entirely | a `data` key holding its `inspect` |

  Everything travels in one hash for that reason, and it is built fresh per
  call rather than handed the caller's — Rollbar deletes a key from the hash it
  is given.

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
