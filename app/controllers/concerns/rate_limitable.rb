module RateLimitable
    extend ActiveSupport::Concern
    
    included do
      before_action :check_rate_limit
    end
    
    private
    
    def check_rate_limit
      key = "rate_limit_#{request.remote_ip}"
      count = Rails.cache.read(key) || 0
      
      if count >= 100
        render json: { error: 'Rate limit exceeded' }, status: :too_many_requests
        return
      end
      
      Rails.cache.write(key, count + 1, expires_in: 1.hour)
    end
end