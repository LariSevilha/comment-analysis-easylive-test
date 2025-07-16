class UserImportJob < ApplicationJob
    queue_as :user_import
    
    def perform(username)
      @processing_job.update!(
        progress_info: "Importing user: #{username}",
        total_items: 1,
        processed_items: 0
      )
      
      user = JsonPlaceholderService.import_user_data(username)
      
      if user
        user.update!(processed: true)

        
        # Trigger metrics calculation
        UserMetricsJob.perform_later(user.id)
        GroupMetricsJob.perform_later
        
        @processing_job.update!(
          processed_items: 1,
          progress_info: "User imported successfully: #{username}"
        )
      else
        raise "User not found: #{username}"
      end
    end
  end