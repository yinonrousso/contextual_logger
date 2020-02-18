# frozen_string_literal: true

require 'spec_helper'
require 'logger'
require 'contextual_logger'
require 'contextual_logger/logger_with_context'
require 'json'

describe ContextualLogger::LoggerWithContext do
  context 'log_level' do
    context "when created with a base logger" do
      let(:log_stream) { StringIO.new }
      let(:base_logger) { ContextualLogger.new(Logger.new(log_stream, level: Logger::Severity::FATAL)) }
      let(:context) { { log_source: "redis_client" } }

      subject(:logger_with_context) { ContextualLogger::LoggerWithContext.new(base_logger, context) }

      it "adds context" do
        subject.fatal("fatal message")
        expect(log_stream.string).to include('{"log_source":"redis_client","message":"fatal message","severity":"FATAL",')
      end

      it "merges context" do
        subject.fatal("fatal message", call_id: "234-123")
        expect(log_stream.string).to include('{"log_source":"redis_client","call_id":"234-123","message":"fatal message","severity":"FATAL",')
      end

      it "allows context to be overridden" do
        subject.fatal("fatal message", log_source: "frontend")
        expect(log_stream.string).to include('{"log_source":"frontend","message":"fatal message","severity":"FATAL",')
      end

      context "context caching" do
        it "caches contexts to avoid merging over and over" do
          subject.fatal("fatal message", log_source: "frontend")
          expect(subject.instance_variable_get(:@merged_context_cache).keys).to eq([{ log_source: "frontend" }])
          subject.fatal("fatal message", log_source: "redis_client")
          expect(subject.instance_variable_get(:@merged_context_cache).keys).to eq([{ log_source: "frontend" }, { log_source: "redis_client" }])
          4998.times do |i|
            subject.fatal("fatal message", log_source: "gem #{i}")
          end
          expect(subject.instance_variable_get(:@merged_context_cache).size).to eq(5000)
          subject.fatal("fatal message", log_source: "gem 5000")
          expect(subject.instance_variable_get(:@merged_context_cache).size).to eq(1)
        end
      end

      context "log level changes" do
        it "defaults to the base log level" do
          expect(subject.level).to eq(Logger::Severity::FATAL)
          log_at_every_level(logger_with_context)
          expect(log_message_levels).to eq(["fatal", "unknown"])
        end

        it "ignores changes to the base log level" do
          subject
          base_logger.level = Logger::Severity::INFO
          log_at_every_level(subject)
          expect(log_message_levels).to eq(["fatal", "unknown"])
        end

        it "can change its own log_level" do
          subject.level = Logger::Severity::INFO
          log_at_every_level(subject)
          expect(log_message_levels).to eq(["info", "warn", "error", "fatal", "unknown"])
        end

        context "when constructed with its own level" do
          subject(:logger_with_context) { ContextualLogger::LoggerWithContext.new(base_logger, context, level: Logger::Severity::WARN) }

          it "respects its own log_level" do
            log_at_every_level(subject)
            expect(log_message_levels).to eq(["warn", "error", "fatal", "unknown"])
          end
        end
      end

      context "for_log_source" do
        subject(:logger_with_context) { ContextualLogger::LoggerWithContext.for_log_source(base_logger, "frontend") }

        it "creates a new logger_with_context using that log_source" do
          subject.fatal("fatal message")
          expect(log_stream.string).to include('{"log_source":"frontend","message":"fatal message","severity":"FATAL",')
        end
      end
    end
  end
end
