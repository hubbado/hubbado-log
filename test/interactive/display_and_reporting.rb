#!/usr/bin/env ruby
# frozen_string_literal: true

# The assembly the automated suite cannot show: both real handlers behind one logger, the real
# Rollbar gem, and an operator changing settings between runs. The same failure five times under
# five settings, with the same message every time so Rollbar groups it into one item.
#
#   ROLLBAR_ACCESS_TOKEN=<server token> bundle exec ruby test/interactive/display_and_reporting.rb
#
# Reported under the environment "verification", pinned below, so a forced failure never sits
# among real incidents. Nothing is written anywhere else and nothing accumulates between runs.
#
# Judge:
#   - Only run 1 prints. Each run announces itself on stdout first, so an ERROR line under any
#     other announcement is a failure.
#   - One Rollbar item, "display and reporting check", with **five** occurrences. Fewer means a
#     setting is still silencing a report, which is what this exists to catch.
#   - The item carries custom.subject "hubbado-log interactive test" and the exception class;
#     the line that printed carries the backtrace.
#   - Run it twice. The second pass behaves the same and the count reaches ten.

require_relative "../test_init"

require "hubbado/log/stderr_logger"
require "hubbado/log/notify_rollbar"
require "rollbar"

token = ENV.fetch("ROLLBAR_ACCESS_TOKEN", nil)

if token.nil? || token.empty?
  abort "ROLLBAR_ACCESS_TOKEN is not set. This test reports to Rollbar for real; without a " \
        "token it would prove nothing that the automated suite does not already prove."
end

# Pinned rather than read from the environment: this files failures on purpose, and an
# ROLLBAR_ENVIRONMENT already set in the shell would put them among real incidents.
ENVIRONMENT = "verification"

Rollbar.configure do |config|
  config.access_token = token
  config.environment = ENVIRONMENT

  # Rollbar narrates every submission, which lands under each run's announcement and reads as
  # though a handler wrote it. What this test is judged on is what our handlers print.
  config.logger = Logger.new(IO::NULL)
end

Hubbado::Log.configuration do |config|
  config.loggers = [Hubbado::Log::StderrLogger, Hubbado::Log::NotifyRollbar]
end

# Both name this diagnostic rather than borrowing a real failure's words: these items sit in a
# Rollbar project beside real incidents, and a reader has to be able to tell them apart.
SUBJECT = "hubbado-log interactive test"
MESSAGE = "display and reporting check"

# A real exception with a real backtrace, which is what a handler is given on the crash path.
def failure
  raise IOError, "connection reset by peer"
rescue IOError => e
  e
end

RUNS = [
  ["_all",          :info,  "the operator asked for everything"],
  ["scan",          :info,  "narrowed to another step"],
  ["",              :info,  "no tags named at all"],
  ["scan,-cookies", :info,  "the failing tag excluded"],
  ["_all",          :fatal, "quietened past an error"]
].freeze

logger = Hubbado::Log::Logger.new(SUBJECT, Hubbado::Log.loggers)

RUNS.each_with_index do |(list, level, description), index|
  Hubbado::Log.config.tags = list
  Hubbado::Log.config.level = level

  $stdout.puts
  $stdout.puts "--- run #{index + 1}: LOG_TAGS=#{list.inspect} LOG_LEVEL=#{level} — #{description}"
  $stdout.puts "    (anything below this line, before the next run, was printed by the handler)"
  $stdout.flush

  logger.error(MESSAGE, failure, tag: :cookies)

  $stderr.flush
end

$stdout.puts
$stdout.puts "Five failures logged. One should have printed; all five should be in Rollbar."
$stdout.puts "Look for one item titled #{MESSAGE.inspect} with five occurrences, environment " \
             "#{ENVIRONMENT.inspect}."
