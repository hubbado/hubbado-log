# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

# [2.0.0 - 2026-08-15]
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
  can now delete their copy. The attributes still read the most recent, derived
  from `messages` rather than assigned beside it, so the two cannot disagree
  about which message is the latest. Note the collection is `messages`, where
  those copies call it `lines` — a project deleting its copy renames its own call
  sites with it.
- `.attach` and `.logger` name `_all` as well as `trace`, so neither the
  configured level nor the configured tag list decides what a spec can read back.
  `.attach` raises a named `ArgumentError` for a class carrying no logger rather
  than failing on nil.

## Changed
- **Breaking:** a log handler receives the tags a message carries, as a `tags:`
  keyword. A handler defined with five parameters raises `ArgumentError` and must
  be updated before upgrading. A handler defined as `def log(*args)` does not
  raise — it silently receives `{tags: []}` as a sixth positional, so check for
  those as well as for the five-parameter shape.
- **Breaking:** a call site cannot pass its data as bare keywords any more. The
  severity methods and `Hubbado::Log.log` now name `tag:` and `tags:`, so
  `logger.info('x', record_id: 7)` raises `ArgumentError: unknown keyword` where
  it previously set `data` to `{record_id: 7}` — Ruby folded the keywords into a
  positional hash while the methods accepted none. Pass the hash explicitly:
  `logger.info('x', { record_id: 7 })`.
- The test suite sets `LOG_TAGS` rather than defaulting it, so a value left in a
  developer's shell cannot decide which tests can write anything.

## Not included
A tag declared once per component, rather than at each call site. There is no
component to declare one for until an application adopts tags, and the shape it
should take is better decided against a real call site than guessed at here.

## Adopting
`LOG_TAGS` is an allow-list: a tagged message is written only if the list names
it, so adding a tag to a call site silences that message everywhere the variable
has not been updated. In a process that also runs Eventide's log gem the one list
decides for both, and untagged messages need `_untagged` in it.

Write the list with no spaces. It is split on commas and nothing else, so
`http, cache` asks for a tag named `http` and another named `⎵cache` — which is
what Eventide does, kept deliberately so one variable means one thing to both.

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
