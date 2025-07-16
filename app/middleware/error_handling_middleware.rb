class ErrorHandlingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)

    # Add request context to logs
    RequestContext.set(
      request_id: request.request_id,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      method: request.method,
      path: request.path,
      params: sanitize_params(request.params)
    )

    start_time = Time.current

    begin
      status, headers, response = @app.call(env)

      # Log successful requests
      duration = ((Time.current - start_time) * 1000).round(2)
      Rails.logger.info({
        message: "Request completed",
        status: status,
        duration_ms: duration,
        request_id: request.request_id
      })

      [status, headers, response]

    rescue => error
      # Log the error with full context
      duration = ((Time.current - start_time) * 1000).round(2)

      Rails.logger.error({
        message: "Request failed",
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(10),
        duration_ms: duration,
        request_id: request.request_id
      })

      # Handle different types of errors
      error_response = handle_error(error, request)

      [error_response[:status], error_response[:headers], [error_response[:body].to_json]]

    ensure
      # Clear request context
      RequestContext.clear
    end
  end

  private

  def handle_error(error, request)
    case error
    when ActionController::ParameterMissing
      {
        status: 400,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'PARAMETER_MISSING',
            message: error.message,
            request_id: request.request_id
          }
        }
      }
    when ActiveRecord::RecordNotFound
      {
        status: 404,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'RECORD_NOT_FOUND',
            message: 'The requested resource was not found',
            request_id: request.request_id
          }
        }
      }
    when ActiveRecord::RecordInvalid
      {
        status: 422,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'VALIDATION_ERROR',
            message: error.message,
            details: error.record&.errors&.full_messages,
            request_id: request.request_id
          }
        }
      }
    when ImportService::UserNotFoundError
      {
        status: 404,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'USER_NOT_FOUND',
            message: error.message,
            request_id: request.request_id
          }
        }
      }
    when ImportService::APIError, TranslationService::APIError
      {
        status: 503,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'EXTERNAL_API_ERROR',
            message: 'External service temporarily unavailable',
            request_id: request.request_id
          }
        }
      }
    when CircuitBreaker::CircuitOpenError
      {
        status: 503,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'SERVICE_UNAVAILABLE',
            message: 'Service temporarily unavailable due to repeated failures',
            request_id: request.request_id
          }
        }
      }
    else
      # Log critical errors for alerting
      CriticalErrorNotifier.notify(error, request) if should_alert?(error)

      {
        status: 500,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          error: {
            code: 'INTERNAL_SERVER_ERROR',
            message: 'An unexpected error occurred',
            request_id: request.request_id
          }
        }
      }
    end
  end

  def sanitize_params(params)
    # Remove sensitive parameters from logs
    sensitive_keys = %w[password token api_key secret]

    params.deep_dup.tap do |sanitized|
      sensitive_keys.each do |key|
        sanitized.delete(key)
        sanitized.delete(key.to_sym)
      end
    end
  rescue
    # If sanitization fails, return empty hash to avoid logging sensitive data
    {}
  end

  def should_alert?(error)
    # Define which errors should trigger alerts
    critical_errors = [
      StandardError, # Catch-all for unexpected errors
      SystemExit,
      NoMemoryError,
      SystemStackError
    ]

    critical_errors.any? { |error_class| error.is_a?(error_class) } &&
      !error.is_a?(ActiveRecord::RecordNotFound) &&
      !error.is_a?(ActionController::ParameterMissing)
  end
end
