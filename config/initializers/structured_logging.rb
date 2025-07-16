require 'logger'

# Custom log formatter for structured logging
class StructuredLogFormatter < Logger::Formatter
  def call(severity, timestamp, progname, msg)
    context = RequestContext.get

    log_entry = {
      timestamp: timestamp.iso8601,
      level: severity,
      message: extract_message(msg),
      context: context
    }

    # Add additional data if msg is a hash
    if msg.is_a?(Hash)
      log_entry.merge!(msg.except(:message))
    end

    # Add progname if present
    log_entry[:component] = progname if progname

    "#{log_entry.to_json}\n"
  end

  private

  def extract_message(msg)
    case msg
    when String
      msg
    when Hash
      msg[:message] || msg['message'] || msg.to_s
    else
      msg.to_s
    end
  end
end


# Add custom log methods to Rails logger
class Logger
  def info_with_context(message, additional_context = {})
    context = RequestContext.get.merge(additional_context)
    info({ message: message }.merge(context))
  end

  def error_with_context(message, error = nil, additional_context = {})
    context = RequestContext.get.merge(additional_context)

    error_data = if error
      {
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(10)
      }
    else
      {}
    end

    error({ message: message }.merge(context).merge(error_data))
  end

  def warn_with_context(message, additional_context = {})
    context = RequestContext.get.merge(additional_context)
    warn({ message: message }.merge(context))
  end
end
