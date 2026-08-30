# Standards for Display Filters Do Not Decide What Is Reported

`hubbado-log` has no standards of its own. These are copied from `metis-hermes-runtime`
(`agent-os/standards/`), following the precedent set by this repo's earlier spec folders. Only the
sections that bind this work are reproduced — the full files are large and mostly Rails-shaped,
which a gem is not.

---

## global/conventions — mixins

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md:42-66`

**This is the standard that decides where a shared display filter can live.** Both printing
handlers need the same tag and level check, and the reflexive answer — a `Filterable` module
included into `StderrLogger` and `RailsLogger` — is the one shape this standard forbids outright.

> **Prefer composition over inheritance, and a mixin is inheritance.** That is the whole of this
> section in one line. In practice it means we do not write mixins: behaviour goes in a
> collaborator, and a module mixed into one of our own classes happens only where a human has said
> yes to that specific case. This is not a preference to be weighed against convenience — it is
> the default position, and the burden of proof sits entirely on anyone proposing a mixin. Give
> the behaviour its own class with its own `dependency` declarations, its own `Substitute` and its
> own spec, and inject it.

> **There is no test seam, so the behaviour is re-proved in every includer.** A mixin cannot be
> substituted — it *is* the object — so every class including it runs the real implementation in
> every one of its own specs, and the shared behaviour gets asserted once per includer.

> **A mixin exists only where a human has approved that specific case — granted by Señor Codigo,
> one at a time, in writing.** Never assumed, never inherited from a neighbouring case, and never
> justified by "the prior art does it" — prior art is a deferred decision, not a design reason.

> **A collaborator is not the answer to everything either — first ask what the thing decides.**
> [...] A module that only wraps the caller's own code [...] decides nothing — it is a shape [...]
> Write a shape where it runs; extract a decision.

Note the standard's own closing line, which is about this gem's subject matter directly:

> a log tag is an allow-list entry, so a drifted spelling writes nothing and nobody is told.

**How it binds:** the display filter *decides* something — whether this message is shown — so it
is a candidate for a collaborator rather than an inlined shape. `LogHandler` is already the real
superclass of all three handlers, so a seam there is ordinary inheritance and not a mixin. Which
of those it becomes is left to TDD; what is settled is that a new module included into our own
handler classes needs an explicit yes first.

---

## global/conventions — naming

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md:14-28`

> **Don't bake the processing mechanism into entity nouns** [...] Symptom: if you find yourself
> reaching for the `<Verb>ing` or `<Verb>tion` form because no obvious noun fits, stop — the noun
> probably exists, and the mechanism leaked into it because it was the easiest name to type.

> **An action is named in the imperative; a past tense is for asking, not for doing.**
> `thing.release(card)` does the releasing. `thing.released?` asks whether it happened.

> **Ubiquitous language — one word from DB through UI**: A domain concept gets a single name and
> that same name is used everywhere.

**How it binds:** whatever the filter is called, it is named for what it *is* to an operator, not
for the mechanism. The domain already has words — a message is *written* or not (`Tags#write?`),
a setting concerns *display*. A predicate asking whether a handler filters is past-tense-or-
question shaped; a thing that performs the check is imperative.

---

## global/conventions — Single Responsibility

Source: `metis-hermes-runtime/agent-os/standards/global/conventions.md:34-40`

> **A class does one thing — and a fused-in second responsibility surfaces as test setup.** [...]
> **The detector is the class's own test.**

**How it binds:** this card exists because `Logger#log` has two responsibilities fused — deciding
what is displayed, and fanning a message out to every destination. The detector fired in
production rather than in a test, which is the expensive way to find it.

---

## testing/test-writing — a behaviour that moves takes its test with it

Source: `metis-hermes-runtime/agent-os/standards/testing/test-writing.md:238-250`

**This governs commit 4.** `test/automated/tags.rb` and `test/automated/level.rb` prove filtering
at the Logger seam today ("reaches the handler"). After the move, that is the wrong seam.

> When a behaviour *moves* (e.g. a model method extracts into a Query class), the test moves with
> it: delete the model-side test, write the query-side test. Don't leave both — the model-side
> becomes a confusing absence-guard while the query-side carries the real contract.

And its companion, on what not to leave behind:

> Don't keep the removed-behaviour test as a "stays-removed" sentinel. The sentinel inverts the
> test-as-contract model — the contract is now the negative, and there's no positive call site to
> fail when the negative is broken.

**How it binds:** the existing tag and level scenarios are re-sited onto the printing handlers,
not duplicated. What is left at the Logger seam is the genuinely new positive contract — the
reporting handler is reached regardless — which is a real assertion with a real failure mode, not
an absence-guard.

---

## testing/test-writing — "Do not test logging", and why it does not apply here

Source: `metis-hermes-runtime/agent-os/standards/testing/test-writing.md:214-220`

Reproduced because a reader will otherwise think this work violates it.

> **Do NOT write tests that assert on logging calls.** Logging is an observability side effect,
> not behaviour. [...] Do NOT stub `Hubbado::Log`, `Rails.logger`, or any other logger to verify
> `warn` / `info` / `error` were called with a particular message. The wording of a log line is
> not a contract — it will change.

> **Don't attach a `LogHandler` or override `.logger` unless an assertion reads it.** [...] is
> only earned by a test that then asserts on `handler` (e.g. `handler.severity == :error`,
> `handler.data.equal?(the_error)` — the sanctioned "exception reaches Rollbar" case).

**How it binds:** the standard governs *other* classes' tests, where logging is a side effect. In
`hubbado-log` the routing of a message **is** the behaviour under test, and the standard names the
exact case this card is about — "the sanctioned 'exception reaches Rollbar' case" — as one where
attaching a handler and asserting on it is earned. No wording of any log line is asserted here;
what is asserted is which destination a message reaches.

---

## testing/controls — control ownership

Source: `metis-hermes-runtime/agent-os/standards/testing/controls.md`

**How it binds:** `Controls::LogHandler.attach` and `.logger` (`controls/log_handler.rb:23,31`)
build a `Logger` with `level:` and `tags:` today, precisely so "neither the configured level nor
the configured tags decide what a spec attaching one of these can read". Once the filters live
below the fan-out, that guarantee has to be produced at the handler instead. The control is this
gem's own, so it moves with the seam.

---

## testing/dependency-injection — substitutes

Source: `metis-hermes-runtime/agent-os/standards/testing/dependency-injection.md:5-73`

Relevant only if the display filter becomes an injected collaborator, in which case its
substitute is the seam the handler specs drive. Not yet decided — see `shape.md`.
