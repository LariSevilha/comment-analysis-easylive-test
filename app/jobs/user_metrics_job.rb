class UserMetricsJob < ApplicationJob
  queue_as :metrics
  
  def perform(user_id)
    user = User.find(user_id)
    
    @processing_job.update!(
      progress_info: "Calculating metrics for user: #{user.username}",
      total_items: 1,
      processed_items: 0
    )
    
    MetricsCalculationService.calculate_user_metrics(user)
    
    @processing_job.update!(
      processed_items: 1,
      progress_info: "User metrics calculated successfully"
    )
  end
end