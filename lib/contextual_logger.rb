# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/module/delegation'
require 'json'
require_relative './contextual_logger/redactor'
require_relative './contextual_logger/context/handler'

module ContextualLogger
  class << self
    def new(logger)
      logger.extend(LoggerMixin)
    end
    deprecate :new, deprecator: ActiveSupport::Deprecation.new('1.0', 'contextual_logger')

    def normalize_log_level(log_level)
      if log_level.is_a?(Integer) && (Logger::Severity::DEBUG..Logger::Severity::UNKNOWN).include?(log_level)
        log_level
      else
        case log_level.to_s.downcase
        when 'debug'
          Logger::Severity::DEBUG
        when 'info'
          Logger::Severity::INFO
        when 'warn'
          Logger::Severity::WARN
        when 'error'
          Logger::Severity::ERROR
        when 'fatal'
          Logger::Severity::FATAL
        when 'unknown'
          Logger::Severity::UNKNOWN
        else
          raise ArgumentError, "invalid log level: #{log_level.inspect}"
        end
      end
    end

    def normalize_message(message)
      case message
      when String
        message
      else
        message.inspect
      end
    end
  end

  module LoggerMixin
    delegate :register_secret, to: :redactor

    def global_context=(context)
      Context::Handler.new(context).set!
    end

    def with_context(context)
      context_handler = Context::Handler.new(current_context_for_thread.deep_merge(context))
      context_handler.set!
      if block_given?
        begin
          yield
        ensure
          context_handler.reset!
        end
      else
        # If no block given, the context handler is returned to the caller so they can handle reset! themselves.
        context_handler
      end
    end

    def current_context_for_thread
      Context::Handler.current_context
    end

    # In methods below, we assume that presence of context means new code that is aware of
    # ContextualLogger...and that that code never uses progname.
    # This is important because we only get 2 args total passed to add(), in order to be
    # compatible with classic implementations like in the plain Logger
    # and ActiveSupport::Logger.broadcast.

    {
      debug:  Logger::Severity::DEBUG,
      info:   Logger::Severity::INFO,
      warn:   Logger::Severity::WARN,
      error:  Logger::Severity::ERROR,
      fatal:  Logger::Severity::FATAL,
      unknown: Logger::Severity::UNKNOWN
    }.each do |method_name, log_level|
      eval <<~EOS
        def #{method_name}(arg = nil, context = nil, &block)
          if context
            add(#{log_level}, arg, context, &block)
          else
            add(#{log_level}, nil, arg, &block)
          end
        end
      EOS
    end

    def log_level_enabled?(severity)
      severity >= level
    end

    def add(arg_severity, arg1 = nil, arg2 = nil, **context)   # Ruby will prefer to match hashes up to last ** argument
      severity = arg_severity || UNKNOWN
      if log_level_enabled?(severity)
        if arg1.nil?
          if block_given?
            message = yield
            progname = arg2 || @progname
          else
            message = arg2
            progname = @progname
          end
        else
          message = arg1
          progname = arg2 || @progname
        end
        write_entry_to_log(severity, Time.now, progname, message, context: current_context_for_thread.deep_merge(context))
      end

      true
    end

    def write_entry_to_log(severity, timestamp, progname, message, context:)
      @logdev&.write(
        redactor.redact(
          format_message(format_severity(severity), timestamp, progname, message, context: context)
        )
      )
    end

    private

    def redactor
      @redactor ||= Redactor.new
    end

    def format_message(severity, timestamp, progname, message, context: {})
      if @formatter
        @formatter.call(severity, timestamp, progname, { message: ContextualLogger.normalize_message(message) }.merge!(context))
      else
        "#{basic_json_log_entry(severity, timestamp, progname, message, context: context)}\n"
      end
    end

    def basic_json_log_entry(severity, timestamp, progname, message, context:)
      message_hash = {
        message:   ContextualLogger.normalize_message(message),
        severity:  severity,
        timestamp: timestamp
      }
      message_hash[:progname] = progname if progname

      # using merge! instead of merge for speed of operation
      message_hash.merge!(context).to_json
    end
  end
end
