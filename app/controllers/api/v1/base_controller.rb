class Api::V1::BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    
    private
    
    def render_success(data, message = 'Success')
      render json: {
        success: true,
        message: message,
        data: data,
        timestamp: Time.current.iso8601
      }
    end
    
    def render_error(message, status = :unprocessable_entity)
      render json: {
        success: false,
        message: message,
        timestamp: Time.current.iso8601
      }, status: status
    end
  end