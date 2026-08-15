# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

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
