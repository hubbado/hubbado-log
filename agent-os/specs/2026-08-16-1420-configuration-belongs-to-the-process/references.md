# References for the process's configuration

## Eventide's log gem — how it avoids this defect entirely

- **Location:** `evt-log-2.1.1.2` (installed gem; also vendored under `hubbado_saas`)
- **Relevance:** `Hubbado::Log`'s subclass mechanism is copied from it verbatim, and its answer to
  "where does the configuration live" is the fix this card needs.

| File | What it shows |
|---|---|
| `lib/log/log.rb:16-33` | `inherited` building a `Dependency` module per subclass — the code this gem copied line for line, including the `self.inherited(self)` call that gives the root class its own module |
| `lib/log/defaults.rb` | The whole configuration: `level`, `tags`, `device`, `formatters` as module methods reading `ENV`. Nothing is held on the `Log` class, so there is nothing for a subclass to fail to inherit |
| `lib/log/log.rb:104-108` | `set_defaults(logger)` — the defaults are stamped onto the *instance* at build time, not consulted through the class at write time |
| `lib/log/registry.rb` | The one class-level instance variable, `@registry ||= {}`. Deliberately per-class — a subclass keeps its own instances — and `||=`-initialised, so it can never answer `nil` |
| `lib/log/log.rb:66-71` | `self.configure(receiver, attr_name:)` — the same signature this gem's `configure` has |

Not applicable here:

- `lib/log/write.rb`, `lib/log/format.rb` — `evt-log` writes to an IO itself. `hubbado-log` fans
  out to handler instances, which is the shape that gives us a second class-level memo to move.
- `lib/log/telemetry.rb` — test observation for a single logger, not a destination.

## A real subclass downstream

```ruby
# evt-messaging-2.7.0.3/lib/messaging/log.rb
module Messaging
  class Log < ::Log
    def tag!(tags)
      tags << :messaging
    end
  end
end
```

Seventeen sibling gems have the same three-line shape. It is the evidence that the subclass path
is used prior art rather than a speculative hook — and the reason this card fixes subclassing
rather than deleting it.

## Where the defect was found

- **Location:** `agent-os/specs/2026-08-15-1300-log-tags/shape.md`, sections "Tags are declared at
  the call site, and only there" and "What TDD settled"
- **Relevance:** Records the diagnosis, and why the fix left with the `tag!` declaration it was
  holding up. That branch was squashed to one commit (`6d452a5`), so the reverted implementation
  is not recoverable from the history — `evt-log` is the reference instead.

## The code being changed

| File | Why it matters |
|---|---|
| `lib/hubbado/log/log.rb:16` | `@config = Configuration.new(...)` — the class-level ivar that is not inherited, and the one place the environment is read |
| `lib/hubbado/log/log.rb:26` | `@loggers ||= config.loggers.map(&:new)` — the second class-level memo, which a subclass would duplicate |
| `lib/hubbado/log/logger.rb:17,21` | `Log.config.level` / `Log.config.tags` — a logger already reads the root class's configuration, whatever class built it |
| `test/automated/log.rb` | How `Log.configuration` and `Log.loggers.first` are exercised today |
| `lib/hubbado/log/controls/log_handler.rb` | `Controls::LogHandler` — keeps every message, answers `logged?` with or without a severity |
