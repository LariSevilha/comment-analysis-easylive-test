class RecalculateAllUsersJob < ApplicationJob
    queue_as :default
  
    def perform 
      User.find_each do |user|
        RecalculateUserMetricsService.new(user).call
      end
    end
  end
  