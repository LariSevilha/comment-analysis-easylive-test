class RecalculateAllUsersJob < ApplicationJob
    def perform
      job = AnalysisJob.create!(job_type: 'recalculate_all_users')
      job.start!
      
      begin
        users = User.analyzed
        job.update!(total_items: users.count)
        
        users.find_each do |user| 
          user.comments.each do |comment|
            next unless comment.translated_body.present?
            comment.analyze_keywords!
          end
           
          MetricsCalculationService.calculate_for_user(user)
          job.increment_progress!
        end
        
        # Recalculate group metrics
        MetricsCalculationService.calculate_group_metrics
        
        job.complete!
        
      rescue StandardError => e
        job.fail!(e.message)
        raise e
      end
    end
  end