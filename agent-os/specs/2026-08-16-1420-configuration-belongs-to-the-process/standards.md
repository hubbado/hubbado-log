# Standards for the process's configuration

`hubbado-log` has no standards of its own. These are copied from `metis-hermes-runtime`
(`agent-os/standards/`). Only the sections that bind this work are reproduced — the full files are
large and mostly Rails-shaped, which a gem is not.

---

## global/conventions — the Dependency module

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md`

This is the standard the defect breaks: the module it tells every class to include is the one
`inherited` builds, and a subclass's copy of it raises.

- **Use `Hubbado::Log::Dependency`, not `Rails.logger`**: For any logging from inside a concept class, `include Hubbado::Log::Dependency` at the top of the class and use the `logger` method it provides. The dependency gives each class its own named logger (tagged with the class name), is substitutable in tests, and composes with the rest of our DI pattern. Don't reach for `Rails.logger` directly — it's a global, ambiguous in log output, and can't be swapped out. Log messages can omit the class prefix because the dependency tags it for you.

  ```ruby
  class MyService
    include Hubbado::Log::Dependency

    def call
      logger.warn("something off: #{detail}")
    end
  end
  ```

- **Levels are filtered by `LOG_LEVEL`, defaulting to `info`**: `hubbado-log` drops any line below the configured level [...] Set it in code with `config.level` when an application wants to decide rather than inherit.

The last clause is the one this card serves: `config.level` has to reach every logger the process
builds, whichever class built it.

---

## global/conventions — naming

Source: same file, "Naming".

- **Don't bake the processing mechanism into entity nouns**: [...] name it for *what it is from the user's perspective*, not for *what the system does to it*. [...] Symptom: if you find yourself reaching for the `<Verb>ing` or `<Verb>tion` form because no obvious noun fits, stop — the noun probably exists, and the mechanism leaked into it because it was the easiest name to type.

- **Ubiquitous language — one word from DB through UI**: A domain concept gets a single name and that same name is used everywhere [...] Translation layers between persistence and display drift.

Binding here on what the built handler instances are called. `Logger#log_handlers` is the name
they already arrive under, and `config.loggers` is the classes — a name this card inherits and
does not resolve.

---

## testing/test-writing — test scope

Source: `metis-hermes-runtime/agent-os/standards/testing/test-writing.md`

- **One test file per behaviour or scenario.** Each file describes one behaviour, scenario, or path through the code. File names are behavioural (`success.rb`, `validation.rb`, `seeds_tidbits.rb`, `missing_params.rb`), not class-shaped (no `_test` suffix).
- **Behaviour-per-file is a guideline, not a hard rule** — a small file holding two or three closely related contexts (e.g. the happy and edge paths of one tightly-scoped contract) is fine; don't split for the sake of splitting. The harder rule is **the filename must describe everything inside the file**.
- **Behaviour-first, not class-first.** The point of a test is to verify behaviour. If you find yourself naming a test file `<class>_test.rb`, ask what behaviour the file actually describes and rename to that.

Why the subclass spec joins `test/automated/dependency_module.rb` rather than getting a file of
its own: the behaviour is "a class that includes the `Dependency` module gets a working logger",
which is exactly what that file already describes. A subclass is another path through it, not a
new subject — and a file named after the fix would name the mechanism, not a behaviour.

---

## testing/test-running

Source: `metis-hermes-runtime/agent-os/standards/testing/test-running.md`

Paths there are Rails-shaped. In this gem:

- The suite: `./test.sh`, which runs `ruby test/automated.rb`
- A single file: `ruby test/automated/<scenario>.rb`

Test Bench prints `passed`/`failed` per `test` block. A non-zero exit code means at least one
assertion failed.

---

## testing/controls

Source: `metis-hermes-runtime/agent-os/standards/testing/controls.md` (34K, not reproduced)

The binding part is the `.example` convention — a control exposes `.example` returning a valid
instance, and variants are named for how they differ. This gem follows it already
(`Controls::Message.example`, `Controls::Subject.example`, `Controls::Data.example`,
`Controls::Exception.example`).

No new control is needed here. `Controls::LogHandler` keeps every message and answers `logged?`
with or without a severity, which is what both new specs read through.
