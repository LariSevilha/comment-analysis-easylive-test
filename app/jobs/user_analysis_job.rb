class UserAnalysisJob < ApplicationJob
    def perform(job_id, username)
      job = AnalysisJob.find(job_id)
      job.start!
      
      begin
        # Import user data
        user = UserAnalysisService.import_user_data(username)
        
        unless user
          job.fail!("User '#{username}' not found")
          return
        end
        
        # Get all comments for processing
        comments = user.comments.where(status: 'novo')
        job.update!(total_items: comments.count)
        
        # Process each comment
        comments.find_each do |comment|
          CommentProcessingService.new(comment).process!
          job.increment_progress!
        end
        
        # Calculate user metrics
        MetricsCalculationService.calculate_for_user(user)
        
        # Recalculate group metrics
        MetricsCalculationService.calculate_group_metrics
        
        job.complete!
        
      rescue StandardError => e
        job.fail!(e.message)
        raise e
      end
    end
  end