# Standards for Tags

`hubbado-log` has no standards of its own. These are copied from `metis-hermes-runtime`
(`agent-os/standards/`), which is where the rule that prompted this card lives. Only the
sections that bind this work are reproduced — the full files are large and mostly Rails-shaped,
which a gem is not.

---

## global/conventions — logging

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md`

The passage at the end of this section is the one card 6839114 quotes, and the one this work
supplies the missing mechanism for.

- **Use `Hubbado::Log::Dependency`, not `Rails.logger`**: For any logging from inside a concept class, `include Hubbado::Log::Dependency` at the top of the class and use the `logger` method it provides. The dependency gives each class its own named logger (tagged with the class name), is substitutable in tests, and composes with the rest of our DI pattern. Don't reach for `Rails.logger` directly — it's a global, ambiguous in log output, and can't be swapped out. Log messages can omit the class prefix because the dependency tags it for you.
  ```ruby
  class MyService
    include Hubbado::Log::Dependency

    def call
      logger.warn("something off: #{detail}")
    end
  end
  ```
  Examples: `Bullhorn::RestAPI`, `Timesheets::ConformBlocks`, `LLMIntegration::Chat`.

- **When to log, and at what severity**: Severity says *what kind of thing happened*, not how interesting it is.

  | Level | Description |
  |---|---|
  | `trace` | Most detailed level of tracing program flow |
  | `debug` | Recording of the completion of a secondary operation of a class or utility, or for recording other details |
  | `info` | Recording of the completion of the principle operation of a class or utility |
  | `warn` | Unexpected state that is not an error, or is recoverable, and that a developer or operator should examine |
  | `error` | Error message logged just prior to raising an error |
  | `fatal` | Message recorded, when possible, as the process is terminating due to an error |

  Three consequences worth stating on their own, because they are the ones that get broken:

  - **`info` marks a completion, and is written where the completion happens** — just above the return of the operation that completed. A method with `logger.info` part-way through it is recording something that has not finished, which is `debug` or `trace`.
  - **There is no "started" line.** "Beginning X" is not a completion of anything, so it has no level. If a reader needs to know a long operation is under way, that is what `trace` on its inner loop is for — the run is visibly moving because the loop is.
  - **The principal operation is what the class is *for*, not the loop that runs it many times.** `Matching` exists to match a card, so each card completed is an `info` line, even though `Matching#call` works a whole board in one go. Batching is scheduling, not purpose. A pass that reports its own totals as well would put the same figures on two streams, since the caller already prints them as its result.
  - **If an iteration of a loop is worth an `info`, the iteration is a method.** A `logger.info` written directly inside a `.each` block is recording the completion of something that has no name. Extract the body and name it for the unit of work — `sweep_row(record_id, row)`, `claim_and_match(entry)` — and the `info` goes just above *its* return. `Dismissal` shows the shape: `matches.each { |row| sweep_row(record_id, row) }`, with the line inside `sweep_row`.

    This is a design rule that logging happens to expose, not a logging rule. Deciding a unit of work is worth announcing is deciding it is a unit of work, and a unit of work that cannot be named is usually not one. If the extracted method resists naming, ask whether the `info` was warranted rather than reaching for a name to satisfy the rule — and if the extracted method starts collecting dependencies of its own, the unit probably wants to be a class (see Single Responsibility above).
  - **A completion must not be quieter than a refusal.** If declining to act on something is `info` — and it usually is, because a skip nobody is told about reads as work that happened — then acting on it cannot be `debug`. Check the two against each other in the same class.

  Detail belongs at the level of the thing it describes, not at the level of the thing it happened inside: a per-candidate line inside a card's work is `trace` even though the card's completion is `info`.

  Levels say what kind of thing happened; they are not a volume control. When a line feels too frequent for `info`, the question to ask is whether it is really a completion — not whether to demote it. A genuine completion that is simply frequent is a filtering problem, not a severity one.

  On `warn`: (a) silent skips where data is dropped or ignored (out-of-range LLM ref, deduplication skip that wasn't expected, malformed input that the code chose to tolerate); (b) recoverable failures of external dependencies (LLM call failed but the job will retry, third-party API returned a non-fatal error); (c) unusual but legal control flow (fallback path taken, cache miss expected to be rare). The test rule: if you `rescue` or `next`/`return` past something surprising, log a warning at that point. The warning should name the field and value so the log alone tells you what to grep next.

  On `error`: raise or re-raise after logging where possible; the exception carries the stacktrace, the log line names the surrounding context (ids, params).

- **Levels are filtered by `LOG_LEVEL`, defaulting to `info`**: `hubbado-log` drops any line below the configured level, so `debug` and `trace` cost nothing when nobody has asked for them. An unattended run — a cron tick — therefore emits one line per principal operation and nothing else. A human watching a run exports `LOG_LEVEL=debug` or `LOG_LEVEL=trace` for the duration. Set it in code with `config.level` when an application wants to decide rather than inherit.

  `LOG_LEVEL` is shared with Eventide's log gem, which writes its own vocabulary into it (`_min`). A name that is not one of the six leaves the level at `info` rather than raising.

- **`warn`/`error`/`fatal` log lines reach Rollbar in production**: The production logger config registers a `Hubbado::Log::NotifyRollbar` handler that forwards `warn` to `Rollbar.warn` and `error`/`fatal` to `Rollbar.error` (dev/test omit it). This is the *only* automatic Rollbar path for failures a job swallows — `Rollbar::ActiveJob` reports unhandled exceptions, so anything you `rescue` without re-raising is invisible to Rollbar unless you log it. Two consequences:
  - **A non-re-raising `rescue` MUST log.** When you rescue an exception to transition a record to a failed state (and deliberately don't re-raise, because retrying would hit the same dead dependency), log it at `error` — or `warn` if the path is genuinely best-effort and degrades gracefully — so an operator still gets paged. Swallowing with no log line is the anti-pattern below.
  - **Pass the exception as the second argument, don't interpolate it.** `logger.error("Tidbit extraction failed", exception)` — not `logger.error("Tidbit extraction failed: #{exception.message}")`. The logger reads the exception's `full_message` for the stacktrace and `NotifyRollbar` hands the exception object to Rollbar, so the message stays a stable, greppable title while the stacktrace and class travel as structured data.

  Anti-patterns: silently swallowing an exception with no log line; warning on every routine event ("warning fatigue"); logging the same condition at multiple severities along the call chain; logging "successfully did X" at `info` for every X in a tight loop (that's `trace`); announcing that something is about to start; `logger.info` part-way through a method; putting the class name in the message (the logger already tags it); interpolating an exception's message into the log string instead of passing the exception object as data.

---

## testing/test-writing — test scope

Source: `metis-hermes-runtime/agent-os/standards/testing/test-writing.md`

## Test scope

- **One test file per behaviour or scenario.** Each file describes one behaviour, scenario, or path through the code. File names are behavioural (`success.rb`, `validation.rb`, `seeds_tidbits.rb`, `missing_params.rb`), not class-shaped (no `_test` suffix). The path mirrors the code under test by default — `test/automated/<concept>/<class>/<scenario>.rb` is a sensible starting layout — but a cross-cutting test can live wherever fits the behaviour it describes.
- **Multiple scenarios under a single directory.** A class with several distinct behaviours becomes a directory with one file per scenario. The lyric_writer tests are the canonical example: `lyric_writer/writes_file.rb`, `lyric_writer/last_path.rb`, `lyric_writer/overwrites.rb`, `lyric_writer/zero_padding.rb`. **Behaviour-per-file is a guideline, not a hard rule** — a small file holding two or three closely related contexts (e.g. the happy and edge paths of one tightly-scoped contract) is fine; don't split for the sake of splitting. The harder rule is **the filename must describe everything inside the file**. A file named `with_track.rb` that also contains "without track" and "rejects legacy `track:` kwarg" tests is broken not because it has multiple contexts but because the name lies about the contents — readers searching for the without-track behaviour won't find it. Either split per scenario, or rename to a name that covers all the contexts (e.g. `track_id_kwarg.rb` when the file tests the contract of a single kwarg across positive, negative, and rejection cases).
- **Behaviour-first, not class-first.** The point of a test is to verify behaviour. If you find yourself naming a test file `<class>_test.rb`, ask what behaviour the file actually describes and rename to that. The same applies to `call.rb`: every service in this codebase exposes its work through `#call`, so naming a test file after the method tells the reader nothing about what's being verified. The directory already says which class is under test — the file name should describe *what `#call` is supposed to do in this scenario*. Prefer short, behavioural names — past participle of the verb the SUT performs, or outcome / state alone: `created.rb`, `destroyed.rb`, `enqueued.rb`, `exists.rb`, `absent.rb`, `success.rb`, `dedup.rb`, `scoped_to_project.rb`. Not `persists_row.rb`, not `enqueues_job_for_new_tidbits.rb`, not `returns_true_when_pair_exists.rb`. The file name is the outcome; the directory and the test descriptions inside fill in the rest. Method names like `new.rb`, `find.rb`, `to_h.rb` are fine where the method itself *is* the behaviour the test describes — they read as actions. `call.rb` is the one to avoid because `#call` is universal and therefore semantically empty.
- **Black-box exceptions**: Occasionally a group of tightly coupled objects is tested as a single unit through one test. This is rare and should be a deliberate decision, not a shortcut.
- **Request tests are smoke tests**: Request tests verify controller wiring — HTTP status, redirects, which component was rendered (CSS hook only), flash messages, response headers, and 403/422 on auth/validation edges. They do NOT run background jobs, stub broadcast renders, assert on enqueued jobs, or loop over collections checking per-item rendered content. See the Request tests section below.
- **Path mirrors the controller, not the route**: Request tests live at `test/automated/<concept>/requests/<resource>/<action>.rb`, mirroring `app/concepts/<concept>/controllers/<resource>_controller.rb#<action>`. **One subdirectory per controller, one file per action.** Examples: `test/automated/songs/requests/tracks/create.rb` tests `Songs::Controllers::TracksController#create` (`POST /concepts/:concept_id/tracks`); `test/automated/projects/requests/tidbits/new.rb` tests `Projects::Controllers::TidbitsController#new`. Even when the controller's resource matches the concept name — `Projects::Controllers::ProjectsController#show` — the subdirectory is kept for consistency: `test/automated/projects/requests/projects/show.rb`. The flat `tracks_create.rb` / `tidbits_new.rb` style is the **wrong** shape; rename to the directory form. Multi-context files (e.g. `tracks/update.rb` with `valid` + `invalid` contexts) stay as a single file until a third scenario lands, at which point split per the **Multiple scenarios under a single directory** rule above into `tracks/update/{valid,invalid,forbidden}.rb`.
- **No schema tests**: Don't write tests that introspect `db/schema.rb` or `ActiveRecord::Base.connection.columns(...)` to assert a column exists, has a default, or is NOT NULL. Schema is already verified by the migration system (it ran or it didn't) and by every model/writer/query test that exercises the column on real rows — those break loudly if the column is wrong. Schema tests duplicate that signal and rot the moment you add a new column without updating them. The trustworthy assertion that a column behaves correctly is a test that uses it.
- **Don't test the framework**: Tests verify *our* behaviour, not Rails'. Skip tests that assert `belongs_to` populates the foreign key, that `has_many` returns the right rows, that `dependent: :destroy` cascades, that an AR column round-trips its value, that `validates_presence_of` rejects nil. Those are Rails features — Rails has its own suite for them, and if any of them broke, half the app would too. Test our model methods (custom predicates, atomic claim methods, derived state like `Concept#dirty?`), unique-index constraints we added in migrations (the index is project code, the cascade is Rails), and any non-trivial scope behaviour. If a test would still pass against a vanilla `class Foo < AR::Base; end` body, it's testing Rails — delete it.

---

## testing/test-running

Source: `metis-hermes-runtime/agent-os/standards/testing/test-running.md`

Paths there are Rails-shaped; in this gem the suite is `./test.sh`, which runs
`ruby test/automated.rb`, and a single file is `ruby test/automated/<scenario>.rb`.

## Testing Standards

- Run the full automated suite: `ruby test/automated.rb`
- Run a single test file: `ruby test/automated/<concept>/<class>/<scenario>.rb`
- Run all tests under a directory: `ruby -r ./test/test_init.rb -e "require 'test_bench/run'; TestBench::Run.('test/automated/<concept>', exclude: '*_init.rb')"`

Test Bench prints `passed`/`failed` per `test` block. A non-zero exit code means at least one assertion failed.

---

## testing/controls

Source: `metis-hermes-runtime/agent-os/standards/testing/controls.md` (34K, not reproduced)

The part that binds here is the `.example` convention: a control exposes `.example` returning a
valid instance, and variants are named for how they differ. This gem already follows it —
`Controls::Message.example`, `Controls::Subject.example`, `Controls::Data.example`,
`Controls::Exception.example` — so the two new controls follow the existing files rather than
the standard directly.
