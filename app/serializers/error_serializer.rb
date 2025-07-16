class ErrorSerializer
  def self.serialize(code, message, details = nil)
    error_response = {
      error: {
        code: code,
        message: message,
        timestamp: Time.current.iso8601
      }
    }

    error_response[:error][:details] = details if details.present?

    error_response
  end

  def self.validation_error(message, details = nil)
    serialize('VALIDATION_ERROR', message, details)
  end

  def self.not_found_error(resource, identifier)
    serialize('NOT_FOUND', "#{resource} not found", "No #{resource.downcase} found with identifier: #{identifier}")
  end

  def self.internal_error(message, details = nil)
    serialize('INTERNAL_ERROR', message, details)
  end
end
