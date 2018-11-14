# frozen_string literal: true

require 'json'

module ContextualLogger
  def self.new(logger)
    logger.extend(self)
  end

  def with_context(context)
    previous_context = Thread.current[THREAD_CONTEXT_NAMESPACE]
    Thread.current[THREAD_CONTEXT_NAMESPACE] = context
    yield if block_given?
  ensure
    Thread.current[THREAD_CONTEXT_NAMESPACE] = previous_context
  end

  def current_context_for_thread
    Thread.current[THREAD_CONTEXT_NAMESPACE] || {}
  end

  def format_message(severity, timestamp, progname, message, context)
    message_with_context = message_with_context(context, message, severity, timestamp, progname)

    if @formatter
      @formatter.call(severity, timestamp, progname, message_with_context)
    else
      "#{message_with_context.to_json}\n"
    end
  end

  def debug(progname = nil, **extra_context, &block)
    add(Logger::Severity::DEBUG, nil, progname, extra_context, &block)
  end

  def info(progname = nil, **extra_context, &block)
    add(Logger::Severity::INFO, nil, progname, extra_context, &block)
  end

  def warn(progname = nil, **extra_context, &block)
    add(Logger::Severity::WARN, nil, progname, extra_context, &block)
  end

  def error(progname = nil, **extra_context, &block)
    add(Logger::Severity::ERROR, nil, progname, extra_context, &block)
  end

  def fatal(progname = nil, **extra_context, &block)
    add(Logger::Severity::FATAL, nil, progname, extra_context, &block)
  end

  def unknown(progname = nil, **extra_context, &block)
    add(Logger::Severity::UNKNOWN, nil, progname, extra_context, &block)
  end

  def add(severity, message = nil, progname = nil, extra_context = nil)
    severity ||= UNKNOWN
    if @logdev.nil? or severity < @level
      return true
    end
    progname ||= @progname
    if message.nil?
      if block_given?
        message = yield
      else
        message = progname
        progname = @progname
      end
    end
    write_entry_to_log(severity, Time.now, progname, message, current_context_for_thread.merge(extra_context))
    true
  end

  def write_entry_to_log(severity, timestamp, progname, message, context)
    @logdev.write(format_message(format_severity(severity), timestamp, progname, message, context))
  end


  private

  THREAD_CONTEXT_NAMESPACE = 'ContextualLoggerCurrentLoggingContext'

  def message_with_context(context, message, severity, timestamp, progname)
    context.merge(
      message: message,
      severity: severity,
      timestamp: timestamp,
      progname: progname
    )
  end
end
