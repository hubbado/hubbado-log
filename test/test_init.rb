ENV["CONSOLE_DEVICE"] ||= "stdout"
ENV["LOG_LEVEL"] ||= "_min"

# Set rather than defaulted: LOG_TAGS is an allow-list, so a value left in the shell decides
# which of these tests can write anything at all. A run has to mean the same thing on a developer's
# machine as on a build agent, and the tests that care about the list set it themselves.
ENV["LOG_TAGS"] = ""

puts RUBY_DESCRIPTION

puts
puts "TEST_BENCH_DETAIL: #{ENV["TEST_BENCH_DETAIL"].inspect}"
puts

require_relative "../init.rb"
require "hubbado/log/controls"

require "debug"
require "test_bench"; TestBench.activate

include Hubbado
