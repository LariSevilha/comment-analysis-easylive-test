class ApplicationController < ActionController::API
  # Set request context for all API requests
  before_action :set_request_context
  after_action :clear_request_context

  private

  def set_request_context
    RequestContext.set(
      request_id: request.request_id,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      method: request.method,
      path: request.path,
      controller: self.class.name,
      action: action_name
    )
  end

  def clear_request_context
    RequestContext.clear
  end

  # Helper method for structured error responses
  def render_error(message, status: :unprocessable_entity, code: nil)
    error_response = {
      error: {
        message: message,
        request_id: request.request_id
      }
    }

    error_response[:error][:code] = code if code

    render json: error_response, status: status
  end

  # Helper method for success responses with consistent structure
  def render_success(data, message: nil, status: :ok)
    response = { data: data }
    response[:message] = message if message
    response[:request_id] = request.request_id

    render json: response, status: status
  end
end
