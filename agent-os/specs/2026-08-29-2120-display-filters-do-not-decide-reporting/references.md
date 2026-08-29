# References for Display Filters Do Not Decide What Is Reported

## The code under change

### `Logger#log` — where both filters sit today

- **Location:** `lib/hubbado/log/logger.rb:23-54`
- **Relevance:** the defect itself. `:30` returns below the level, `:43` returns outside the tag
  list, and `:51-53` fans out to every handler. Both filters are above the fan-out, so both decide
  `NotifyRollbar` as well as `StderrLogger`.
- **Key detail:** `:39-41` already carries a comment explaining that both filters have to pass and
  that neither can rescue a message the other drops. That comment becomes false and is part of the
  change.

### `NotifyRollbar` — the handler that already knows what it wants

- **Location:** `lib/hubbado/log/notify_rollbar.rb:12,20-22`
- **Relevance:** `LEVELS` maps only `warn`, `error`, `fatal` and `unknown`; `#log` returns
  immediately when the severity is not in it. The handler self-selects, so a level filter upstream
  of it is redundant as well as harmful. Expected to need no change at all.

### `Tags` — the predicate that moves, unchanged

- **Location:** `lib/hubbado/log/tags.rb:43-53`
- **Relevance:** `#write?` is the whole decision, and it is not being altered — only relocated.
  That is what keeps the `evt-log` parity criterion satisfiable: a printed line's semantics are
  identical, including the awkward parts the class documents (`_all` answered before any
  exclusion, so `_all,-data` writes `data` messages regardless).

### `Controls::LogHandler` — the test seam that follows the filters down

- **Location:** `lib/hubbado/log/controls/log_handler.rb:14,28`
- **Relevance:** `.attach` and `.logger` build `Log::Logger.new(..., level: :trace, tags:
  Tags::ALL)` so that "neither the configured level nor the configured tags decide what a spec
  attaching one of these can read". That guarantee has to be reproduced at the handler.
- **Also:** these two are the *only* callers of the per-logger overrides anywhere in the monorepo.

## Prior art in this repo

### The three earlier spec folders

- **Location:** `agent-os/specs/2026-08-15-1300-log-tags/`,
  `agent-os/specs/2026-08-16-1420-configuration-belongs-to-the-process/`,
  `agent-os/specs/2026-08-16-2337-stderr-logger-ships-with-the-gem/`
- **Relevance:** `log-tags` is where the filter this card moves was introduced;
  `stderr-logger-ships-with-the-gem` established the precedent of borrowing
  `metis-hermes-runtime`'s standards, in the same words this spec's `standards.md` reuses.

### Existing filter specs

- **Location:** `test/automated/tags.rb`, `test/automated/level.rb`
- **Relevance:** the behaviour that moves. Both are written at the Logger seam — every scenario
  asserts "reaches the handler" / "reaches no handler" against a single
  `Controls::LogHandler`. Under the change they belong to the printing handlers.
- **Key patterns to keep:** the scenario names read as operator intent ("The operator names a
  tag", "The operator excludes a tag", "A message marked as written regardless"), and
  `tags.rb:116` already composes tags with the level. `tags.rb` also holds the one spec of the
  per-logger override — "A logger naming its own tags / Follows its own rather than the
  operator's".

## Upstream — `evt-log` and its family

### `Log::Filter` — the predicate `Tags` follows branch for branch

- **Location:** `<any component>/gems/ruby/4.0.0/gems/evt-log-2.1.1.2/lib/log/filter.rb:20-45`
- **Relevance:** `write_tag?` answers `:*` before any list is consulted, which is what lets a call
  site put a line beyond an operator's reach. `Tags#write?` mirrors it clause for clause, so the
  parity criterion is checked against this file.

### `Log::Write` — proof that upstream has no fan-out

- **Location:** `evt-log-2.1.1.2/lib/log/write.rb:17-19`, `lib/log.rb:42-44`
- **Relevance:** `device.write(message)` against a single IO, plus a telemetry sink used only for
  test assertions. There is nothing behind the filters but one stream, which is why upstream does
  not have this defect and why moving the filters is a correction rather than a divergence.

### `ComponentHost::Host` — reporting outside the logger

- **Location:** `evt-component_host-2.1.0.1/lib/component_host/host.rb:98-99`
- **Relevance:** upstream's own answer. `record_errors_observer.(error)` reports with no logger and
  no filter; `logger.fatal(tags: [:*, :component_host, :start])` prints, marked so narrowing
  cannot hide it. Two acts, one line each. `evt-consumer/lib/consumer/consumer.rb:137-138` and
  `:55-57` show the same split, with `error_raised` as the seam a consumer overrides to report.

### The counter-example

- **Location:** `evt-consumer/lib/consumer/handler_registry.rb:25`
- **Relevance:** logs at error, untagged, so any `LOG_TAGS` without `:_untagged` suppresses it.
  Upstream is not perfectly consistent about its own `:*` convention — evidence that a convention
  remembered at every call site is not a fix.

## The measurement

### The forced-crash comparison

- **Location:** `metis-hermes-runtime/projects/hubbado-attio`, `test/interactive/error_reporting.rb`
  and `test/interactive/rollbar_grouping.rb`
- **Relevance:** how the defect was found and how the fix is proved. `rollbar_grouping.rb:164`
  builds `Hubbado::Log::Logger.new("RollbarGroupingProbe", Hubbado::Log.loggers)` directly, which
  is the shape the end-to-end check reuses against a path-sourced gem.

### Production configuration

- **Location:** `infrastructure/kubernetes/hubbado/production/config-map.yaml:52,57`,
  `hubbado_saas/hubbado_core/config/environments/production.rb:228-232`
- **Relevance:** the named `LOG_TAGS` list and the `RailsLogger, NotifyRollbar` pairing that
  together arm the defect in production. `LOG_LEVEL` is `info` today.
- **Contrast:** `infrastructure/kubernetes/eco/production/config-map.yaml:14` is `LOG_TAGS: _all`,
  and eco is on 1.0.1 besides.

### The independent sighting

- **Location:** `work-logs/sam-stickland-2026.md:8359-8365`
- **Relevance:** the Cloud Logging cost investigation routed a volume cut through `LOG_LEVEL`
  rather than `LOG_TAGS` specifically because the "whitelist/blacklist semantics could
  accidentally suppress errors". The same trap, found from the opposite direction, and the source
  of the standing `LOG_LEVEL: "warn"` recommendation that makes the level half of this card
  urgent.
