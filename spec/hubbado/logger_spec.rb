require 'spec_helper'
require "hubbado/logger"
require 'ffaker'

RSpec.describe Hubbado::Logger do
  let(:dummy_log_handler_class) do
    Class.new(described_class::LogHandler) do
      attr_accessor :severity
      attr_accessor :message
      attr_accessor :data
      attr_accessor :stacktrace

      def initialize
        self.severity = nil
        self.message = nil
        self.data = nil
        self.stacktrace = nil
      end

      def log(severity, message, data = nil, stacktrace = nil)
        self.severity = severity
        self.message = message
        self.data = data
        self.stacktrace = stacktrace
      end
    end
  end

  let(:logger) { described_class.new(handler) }

  describe '#log' do
    let(:handler) { dummy_log_handler_class.new }
    let(:message) { FFaker::HipsterIpsum.sentence }
    let(:severity) { :info }
    let(:stacktrace) { Array.new(10) { FFaker::HipsterIpsum.sentence } }
    subject(:log) { logger.log(severity, message) }

    before do
      allow(Kernel).to receive(:caller).and_return(stacktrace)
    end

    context 'with an invalid severity' do
      let(:severity) { 'DEADBEEF' }

      it 'raises an exception' do
        expect {
          log
        }.to raise_error ArgumentError
      end
    end

    %i[debug info].each do |level|
      context "when the severity is #{level}" do
        let(:severity) { level }

        it 'passes details without a stacktrace to the log handler' do
          log

          expect(handler).to have_attributes(
            severity: severity,
            message: message,
            data: nil,
            stacktrace: nil
          )
        end
      end
    end

    %i[warn error fatal unknown].each do |level|
      context "when the severity is #{level}" do
        let(:severity) { level }

        it 'passes details with a stacktrace to the log handler' do
          log

          expect(handler).to have_attributes(
            severity: severity,
            message: message,
            data: nil,
            stacktrace: stacktrace.join("\n")
          )
        end
      end
    end

    context 'with regular data' do
      let(:severity) { :info }
      let(:data) do
        {
          one: { sample: 1, random: 'DEADBEEF' },
          two: [1, 2, 3]
        }
      end

      it 'passes details with data to the log handler' do
        logger.log(severity, message, data)

        expect(handler).to have_attributes(
          severity: severity,
          message: message,
          data: data,
          stacktrace: nil
        )
      end
    end

    context 'when the data is an exception' do
      let(:severity) { :error }

      # This raise and rescue method seems necessary to ensure that the exception has a stable
      # stacktrace
      it 'passes the Exception.full_message as the stacktrace' do
        begin
          raise ArgumentError, "Some message"
        rescue ArgumentError => exception
          logger.log(severity, message, exception)

          expect(handler).to have_attributes(
            severity: severity,
            message: message,
            data: exception
          )

          expect(handler.stacktrace).to eq exception.full_message
        end
      end
    end
  end
end
