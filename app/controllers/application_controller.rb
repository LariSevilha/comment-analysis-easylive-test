class ApplicationController < ActionController::Base
  protect_from_forgery with: :null_session
  
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActionController::ParameterMissing, with: :bad_request
  
  private
  
  def not_found(exception)
    render json: { error: 'Not found', message: exception.message }, status: :not_found
  end
  
  def bad_request(exception)
    render json: { error: 'Bad request', message: exception.message }, status: :bad_request
  end
end