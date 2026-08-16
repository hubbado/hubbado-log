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
  def log(subject, severity, message, data = nil, stacktrace = nil)
    ...
  end
end
```

`data` is whatever the call site passed as the second argument, and is an `Exception` when it
logged one. `stacktrace` is the exception's `full_message` in that case, and otherwise the caller
stack, synthesised for `warn`, `error`, `fatal` and `unknown` only.

### `Hubbado::Log::StderrLogger`

The one handler this gem ships, because `$stderr` is owned by nobody and every command-line tool
wants it. It is not loaded by `require 'hubbado/log'` — ask for it:

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

## Level

A message below the level reaches no handler.

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

A single logger can name its own with
`Hubbado::Log::Logger.new(subject, handlers, level: :debug)`.

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

Which tagged messages are written is decided by `LOG_TAGS`, a comma-separated list:

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

A single logger can name its own list, as it can name its own level, so one component can be
read without turning up everything around it:

```ruby
Hubbado::Log::Logger.new(subject, handlers, level: :trace, tags: '_all')
```

The syntax and its behaviour are Eventide's log gem, copied deliberately so that a string an
operator writes means the same thing in both codebases. Two consequences of that are worth
knowing before adopting tags:

- **`LOG_TAGS` is an allow-list.** A tagged message is written only if the list names it. Adding
  a tag to a call site therefore *silences* that message everywhere `LOG_TAGS` has not been
  updated — cron, CI and production included. Ship the variable with the tag.
- **There is no way to mute one concern and keep the rest.** `-name` subtracts only from
  messages an include has already matched, and `_all` is answered before any exclusion, so
  `_all,-data` still writes `data` messages. Keeping everything except one concern means naming
  the others.

`LOG_TAGS` is shared with Eventide's log gem, as `LOG_LEVEL` is. In a process running both, one
list decides for both, and an application whose messages are all untagged goes silent unless the
list contains `_untagged`.

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

Three questions, each taking an optional severity:

| Call | Answers |
|---|---|
| `logged?` / `logged?(:warn)` | whether anything was written, at all or at that severity |
| `messages` / `messages(:warn)` | what it said — the message strings, in order |
| `logged` / `logged(:warn)` | everything about what it said |

`logged` answers with entries carrying `severity`, `message` and `data`, for the assertion that
needs more than the text:

```ruby
assert logger.logged(:error).first.data.equal?(exception)
```

`messages` and `logged?` are both derived from `logged`, so the three cannot disagree about what
counts as written at a severity.

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
