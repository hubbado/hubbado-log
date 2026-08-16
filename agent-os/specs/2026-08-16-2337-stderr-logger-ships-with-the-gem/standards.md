# Standards for StderrLogger Ships With The Gem

`hubbado-log` has no standards of its own. These are copied from `metis-hermes-runtime`
(`agent-os/standards/`). Only the sections that bind this work are reproduced — the full files are
large and mostly Rails-shaped, which a gem is not.

---

## global/conventions — what each severity means

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md:162-171`

This is the standard that decides where the stacktrace line is drawn. The handler prints a
synthesised stacktrace at `error` and above and stays quiet at `warn`, and the justification is
here rather than in the code: an `error` is logged just prior to raising, so it is a failure
somebody has to find; a `warn` is a condition somebody should examine, and the message already
names the field and value.

> **When to log, and at what severity**: Severity says *what kind of thing happened*, not how
> interesting it is.
>
> | Level | Description |
> |---|---|
> | `trace` | Most detailed level of tracing program flow |
> | `debug` | Recording of the completion of a secondary operation of a class or utility, or for recording other details |
> | `info` | Recording of the completion of the principle operation of a class or utility |
> | `warn` | Unexpected state that is not an error, or is recoverable, and that a developer or operator should examine |
> | `error` | Error message logged just prior to raising an error |
> | `fatal` | Message recorded, when possible, as the process is terminating due to an error |

The same section adds, on `warn`:

> The test rule: if you `rescue` or `next`/`return` past something surprising, log a warning at that
> point. The warning should name the field and value so the log alone tells you what to grep next.

and on `error`:

> raise or re-raise after logging where possible; the exception carries the stacktrace, the log
> line names the surrounding context (ids, params).

Note the phrasing: *the exception carries the stacktrace*. That is the case the handler must not
print twice.

---

## global/conventions — an exception is data, not a string

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md`, the Rollbar bullet

This is the call-site rule the handler's `data.is_a?(Exception)` branch exists to serve. If call
sites obeyed it only sometimes, the branch would be guesswork; because the standard is explicit,
the branch is a contract.

> **Pass the exception as the second argument, don't interpolate it.**
> `logger.error("Tidbit extraction failed", exception)` — not
> `logger.error("Tidbit extraction failed: #{exception.message}")`. The logger reads the exception's
> `full_message` for the stacktrace and `NotifyRollbar` hands the exception object to Rollbar, so
> the message stays a stable, greppable title while the stacktrace and class travel as structured
> data.

The same bullet establishes what the handlers are collectively for:

> **`warn`/`error`/`fatal` log lines reach Rollbar in production**: The production logger config
> registers a `Hubbado::Log::NotifyRollbar` handler that forwards `warn` to `Rollbar.warn` and
> `error`/`fatal` to `Rollbar.error` (dev/test omit it). This is the *only* automatic Rollbar path
> for failures a job swallows.

Two consequences for this work. First, the handler being added here is the *other* half of that
pair — what a person sees live, where Rollbar is what a person finds later. Second, it confirms the
`Hubbado::Log::NotifyRollbar` name is already in the standard, so `Hubbado::Log::StderrLogger`
needs no new vocabulary.

---

## global/code-organization — explicit require chains

Source: `metis-hermes-runtime/agent-os/standards/global/code-organization.md`

> `/lib` holds domain code with explicit `require_relative` chains

Applied here: the new file requires what it needs rather than assuming load order, because an
opt-in require is by definition loaded on its own. This is also the shape
`lib/hubbado/log/controls.rb` already has.

---

## testing/test-writing — behaviour per test

Source: `metis-hermes-runtime/agent-os/standards/testing/test-writing.md`

> Behaviour-per-file scenario layout

Applied here as seven `test` blocks, one behaviour each, in one file named for the class — which is
the behaviour, since a handler has a single public responsibility.

---

## What is deliberately not applied

- **`testing/controls.md`** — a control is the shared editing locus for a *shape*. A `StringIO`
  passed through the existing `io:` keyword is not a shape, and adding a control for one would be
  the "no hooks without implementers" trap.
- **The `Hubbado::Log::Controls::LogHandler` bullet** (`conventions.md:234-263`) — it governs how a
  *consumer* proves its class logged something. This spec tests a handler's rendering, which is the
  case that bullet explicitly carves out: "`Controls::LogHandler` is for a spec where a handler
  receiving, or not receiving, a message is itself the subject". Reading printed output is a third
  case again, and is why this is the first spec in the repo to capture `io`.
- **Everything Rails-shaped** — controllers, forms, components, Turbo, ActiveRecord. A gem has none
  of it.
