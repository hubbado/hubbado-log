# Hubbado::Logger

This is an extremely lightweight, pluggable logging system

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'hubbado-logger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install hubbado-log

## A class's own logger

A class that includes the dependency module gets a `logger` writing under its own name:

```ruby
class MyService
  include Hubbado::Log::Dependency

  def call
    logger.info('Did the thing')
  end
end
```

A subclass carries a dependency module of its own, so a library or a component can name where
its classes take their logger from:

```ruby
module Messaging
  class Log < Hubbado::Log; end
end

class Handler
  include Messaging::Log::Dependency
end
```

Either way the logger writes through the handlers the process was configured with, at the level
and tags it was configured for.

## Handlers

A handler is what a log line is finally written *to*. The process names them, and the log system
builds each one itself with no arguments:

```ruby
Hubbado::Log.configuration do |config|
  config.loggers = [Hubbado::Log::StderrLogger]
end
```

Handlers mostly belong to the application rather than to this gem, because what they write to is
the application's — a Rails logger, a Rollbar token. Write one by subclassing
`Hubbado::Log::LogHandler` and implementing `log`:

```ruby
class MyHandler < Hubbado::Log::LogHandler
  def log(subject, severity, message, data = nil, stacktrace = nil, tags = [])
    return unless Hubbado::Log::Display.shows?(severity, tags)

    ...
  end
end
```

`data` is whatever the call site passed as the second argument, and is an `Exception` when it
logged one. `stacktrace` is the exception's `full_message` in that case, and otherwise the caller
stack, synthesised for `warn`, `error`, `fatal` and `unknown` only. `tags` is what the message was
tagged with, as symbols.

**A handler that writes where a person reads asks `Display.shows?` first**, and one that reports
an incident does not — see [Display and reporting](#display-and-reporting).

### `Hubbado::Log::StderrLogger`

For a command-line tool, where the log is a person watching a run. It is not loaded by
`require 'hubbado/log'` — ask for it:

```ruby
require 'hubbado/log/stderr_logger'
```

It prints the severity, the subject and the message on one line, and anything the line carried
below it:

    WARN Scanning::Sweep: rec_1 skipped, no rate
    ERROR Scanning::Sweep: rec_2 refused
    /app/lib/scanning/sweep.rb:41:in 'post': HTTP 400 (RequestError)
      from /app/lib/scanning/sweep.rb:12:in 'call'

A stacktrace prints at `error` and above, and only when the data is not an exception — an
exception already prints its own backtrace, so honouring both would print it twice. A `warn`
stays one line: it is a condition to examine rather than a failure to trace, and a sweep that
warns per row would otherwise bury itself in Ruby stack.

Pass `io:` to write somewhere else, which is mainly how a spec reads it back:

```ruby
Hubbado::Log::StderrLogger.new(io: StringIO.new)
```

### `Hubbado::Log::RailsLogger`

Writes into a Rails application's own log.

```ruby
require "hubbado/log/rails_logger"

Hubbado::Log.configuration do |config|
  config.loggers = [Hubbado::Log::RailsLogger]
end
```

Rails is not a dependency of this gem. The constant is read lazily, and the only place a handler
is ever registered is an environment file, where Rails is loaded by definition.

The subject and message go on one line, and the data and stacktrace on lines below it, all at the
severity of the line. An exception is one line rather than two — its backtrace already carries the
message that its `inspect` would repeat. `trace` is written as `debug`, because Rails' logger has
no method below it, and a handler passing `trace` straight through raises `NoMethodError` on the
first trace line it is handed.

Unlike the stderr handler, the stacktrace is written at every severity. A Rails log is read after
the fact, and by machine as often as by a person, so there is nothing to keep readable by
withholding frames.

Pass `rails_logger:` to write somewhere else, which is mainly how a spec reads it back. Left
unset, `Rails.logger` is read on every line rather than held, so a handler built before Rails
replaced its logger still writes to the current one.

### `Hubbado::Log::NotifyRollbar`

Forwards a line worth an incident to Rollbar: `warn` as a warning, `error`, `fatal` and
`unknown` as errors, and anything below a warning not at all.

**Rollbar is not a dependency of this gem.** It is a development dependency, so nothing about
installing `hubbado-log` installs Rollbar. A consumer that wants this handler puts `rollbar` in
its own Gemfile and requires the handler itself:

```ruby
require "hubbado/log/notify_rollbar"

Hubbado::Log.configuration do |config|
  config.loggers = [Hubbado::Log::StderrLogger, Hubbado::Log::NotifyRollbar]
end
```

The require raises `LoadError` at boot if Rollbar is absent, which is deliberate — the
alternative is a `NameError` raised inside `log`, at the moment something is trying to report a
failure, replacing the error being reported with a worse one.

The handler configures nothing. Access token, environment and scrubbing are Rollbar's own
`Rollbar.configure`, which the application owns.

Everything the line carried travels as Rollbar's extra data, in **one** hash — Rollbar scans its
arguments by type and keeps the last hash it is given, so a second one would silently displace
the first:

| The line has | Reaches the item as |
|---|---|
| an exception as its data | the exception itself, which Rollbar groups and traces on |
| a hash as its data | those keys, stringified |
| anything else as its data | a `data` key holding its `inspect` |
| — | a `subject` key naming the class that logged it |
| a stacktrace, with no exception | a `stacktrace` key |

The handler's own keys are merged last, so a line cannot tell an item it came from a different
class. A stacktrace is sent only when there is no exception, because Rollbar reads the backtrace
off an exception itself.

The message is sent as a String whatever it was — Rollbar matches its title by type, so anything
else would leave the item with no title at all.

Pass `notifier:` to record what was sent rather than send it, which is mainly how a spec reads it
back.

## Level

A message below the level is not displayed. It still reaches a handler that reports — see
[Display and reporting](#display-and-reporting).

```ruby
Hubbado::Log.configuration do |config|
  config.loggers = [Hubbado::Log::StderrLogger]
  config.level = :debug
end
```

Without `config.level`, the level comes from the `LOG_LEVEL` environment variable:

    $ LOG_LEVEL=debug ./my-command

It defaults to `info`, so `debug` and `trace` are off until they are asked for.

Levels, lowest first:

| Level | What it records |
|---|---|
| `trace` | Most detailed tracing of program flow |
| `debug` | Completion of a secondary operation of a class or utility, or other details |
| `info` | Completion of the principal operation of a class or utility |
| `warn` | Unexpected state that is not an error, or is recoverable, and that a developer or operator should examine |
| `error` | Message logged just prior to raising an error |
| `fatal` | Message recorded, when possible, as the process is terminating due to an error |

`LOG_LEVEL` is shared with Eventide's log gem, which writes names this gem does not
know. A name that is not one of `debug`, `info`, `warn`, `error`, `fatal` or
`unknown` leaves the level at `info` rather than raising.

## Tags

A level says what kind of thing happened. A tag says which concern it belongs to, so a
completion that is simply frequent can be filtered out without being demoted to `debug`.

Name the concern where the message is written. `tag:` and `tags:` are both accepted, and a
message can use either or both:

```ruby
logger.info('Invoice raised', tags: [:invoicing, :billing])
logger.trace('Row read', tag: :data)
```

### `LOG_TAGS`

Which tagged messages are displayed is decided by `LOG_TAGS`, a comma-separated list:

    $ LOG_TAGS='_untagged,-data,billing,invoicing' ./my-command

| Entry | Meaning |
|---|---|
| `name` | Write messages carrying this tag |
| `-name` | Do not write messages carrying this tag, even if another entry includes them |
| `_untagged` | Write messages carrying no tag at all |
| `_all` | Write every message, whatever it carries |

A message can also tag itself `:*`, which writes it whatever the list says.

**Write the list with no spaces.** It is split on commas and nothing else, so `http, cache`
asks for a tag named `http` and another named `⎵cache`, which nothing carries. This is
Eventide's behaviour, kept deliberately so one `LOG_TAGS` means the same thing to both gems.

Tags compose with the level rather than replacing it: both filters have to pass, so a tag
cannot raise a message above the level and the level cannot rescue one the list leaves out.
Both decide what is displayed, and neither decides what is reported.

The syntax and its behaviour are Eventide's log gem, copied deliberately so that a string an
operator writes means the same thing in both codebases. Two consequences of that are worth
knowing before adopting tags:

- **`LOG_TAGS` is an allow-list.** A tagged message is displayed only if the list names it. Adding
  a tag to a call site therefore *hides* that message everywhere `LOG_TAGS` has not been
  updated — cron, CI and production included. Ship the variable with the tag.
- **There is no way to mute one concern and keep the rest.** `-name` subtracts only from
  messages an include has already matched, and `_all` is answered before any exclusion, so
  `_all,-data` still writes `data` messages. Keeping everything except one concern means naming
  the others.

`LOG_TAGS` is shared with Eventide's log gem, as `LOG_LEVEL` is. In a process running both, one
list decides for both, and an application whose messages are all untagged goes silent unless the
list contains `_untagged`.

## Display and reporting

`LOG_LEVEL` and `LOG_TAGS` decide what is displayed. They do not decide what is reported: an
operator narrowing to the step they are debugging is asking to be shown less, not asking for a
crash elsewhere to go unreported.

The logger fans every message out to every handler. A handler that writes where a person reads
asks whether the operator wanted to be shown it; one that reports does not:

```ruby
Hubbado::Log::Display.shows?(severity, tags)   # => true if LOG_LEVEL and LOG_TAGS both admit it
```

`StderrLogger` and `RailsLogger` ask. `NotifyRollbar` does not: it is reached whatever the operator
narrowed or quietened to, and declines anything below `warn` itself.

**A printing handler that forgets to ask prints everything**, whatever the operator set. That is
the one thing to remember when writing one.

Tagging a `warn` no longer hides it from Rollbar, only from the terminal — and `:*` now means
"always display", which is what it means in Eventide's log gem.

## Reading back what a class logged

A spec assigns a substitute where the class's logger goes, and then asks what the class said:

```ruby
require 'hubbado/log/controls'

instance.logger = Hubbado::Log::Controls::Logger.example

instance.()

assert instance.logger.logged?(:error)
```

For a class handed a logger rather than carrying one — the shape a CLI usually takes — it is the
same object, passed in:

```ruby
logger = Hubbado::Log::Controls::Logger.example

CLI.run(argv, logger: logger)

assert logger.logged?(:error)
```

It records what it was told rather than writing, so no handler is involved and neither the
configured level nor `LOG_TAGS` decides what can be read back.

Three questions, each taking the same criteria:

| Call | Answers |
|---|---|
| `logged?` | whether a line matching was written |
| `messages` | what those lines said — the message strings, in order |
| `logged` | everything about them |

| Criterion | Names a line by |
|---|---|
| a severity, positionally | `logged?(:warn)` |
| `message:` | a String matching in full, or a Regexp matching part |
| `tags:` | the tags it carries, compared as a set — one symbol or a list |

**Name them together rather than one at a time.** A run writes several lines, and a message and a
tag list asserted apart can each be true of a different one:

```ruby
assert logger.logged?(:info, message: /handed back/, tags: %i[rescoring sweep])
```

`tags:` names every tag the line carries and no others, in any order. It reads both keywords as
the logger does, so a call site rewritten from `tag: :claim` to `tags: [:claim]` — a change with
no behaviour in it — does not break the spec.

`logged` answers with entries carrying `severity`, `message`, `data` and `tags`, for the assertion
that needs more than a yes:

```ruby
assert logger.logged(:error).first.data.equal?(exception)
```

`messages` and `logged?` are both derived from `logged`, so the three cannot disagree about which
lines are being talked about.

A severity reaches a logger two ways — `logger.warn('…')` names it as the method,
`logger.log(:warn, '…')` as an argument — and both answer the same question, compared as symbols.

The substitute is a mimic of `Logger`, so it answers `is_a?(Hubbado::Log::Logger)` for a class
that checks, and gains any method `Logger` gains.

Prefer `logged?` to reaching into `messages` where it will do. That a failure was reported is
usually the contract; the wording of the line usually is not.

### Testing a handler

`Controls::LogHandler` is for specs where a handler receiving — or not receiving — a message is
itself the subject, which in practice means this gem's own tests of level and tag filtering. A
consumer asserting that its class logged something wants the substitute above.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/hubbado/hubbado-logger.
