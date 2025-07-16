class ApplicationController < ActionController::API
  rescue_from StandardError, with: :handle_standard_error
  
  private
  
  def handle_standard_error(exception)
    Rails.logger.error "#{exception.class}: #{exception.message}\n#{exception.backtrace.join("\n")}"
    
    render json: {
      error: 'Internal server error',
      message: exception.message
    }, status: :internal_server_error
  end
end