class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing
  
  private
  
  def record_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end
  
  def parameter_missing(exception)
    render json: { error: exception.message }, status: :bad_request
  end
end