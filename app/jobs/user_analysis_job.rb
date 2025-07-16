class UserAnalysisJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error "Deserialization error in UserAnalysisJob: #{error.message}\n#{error.backtrace.join("\n")}"
  end

  retry_on StandardError, wait: 5.seconds, attempts: 3 do |job, error|
    Rails.logger.error "Retrying UserAnalysisJob (job_id: #{job.job_id}): #{error.message}\n#{error.backtrace.join("\n")}"
  end

  def perform(job_id, username)
    Rails.logger.info "UserAnalysisJob started with job_id: #{job_id.inspect}, username: #{username.inspect}"
    
    raise ArgumentError, "Missing job_id" unless job_id
    raise ArgumentError, "Missing username" unless username

    job = AnalysisJob.find(job_id)
    job.mark_as_running!

    Rails.logger.info "Starting user analysis for: #{username}"
    
    begin
      job.update_progress(0, 100, "Importing user data...")
      user, total_comments = UserAnalysisService.import_user_data(username)
      
      if user.nil?
        job.mark_as_failed!("User not found: #{username}")
        Rails.logger.warn "User not found: #{username}"
        return
      end

      job.update_progress(20, 100, "Processing #{total_comments} comments...")
      
      processed_count = 0
      user.comments.find_each do |comment|
        comment.process_comment!
        processed_count += 1
        
        if processed_count % 5 == 0
          percentage = 20 + (processed_count.to_f / total_comments * 60)
          job.update_progress(percentage, 100, "Processed #{processed_count}/#{total_comments} comments")
        end
      end

      job.update_progress(80, 100, "Calculating user metrics...")
      RecalculateUserMetricsService.new(user).call
      
      job.update_progress(90, 100, "Updating group metrics...")
      RecalculateGroupMetricsService.new.call
      MetricsService.invalidate_cache
      
      job.update_progress(100, 100, "Analysis completed")
      job.mark_as_completed!
      
      Rails.logger.info "User analysis completed for: #{username}"
      
    rescue StandardError => e
      Rails.logger.error "User analysis failed for #{username}: #{e.message}\n#{e.backtrace.join("\n")}"
      job.mark_as_failed!(e.message)
      raise
    end
  end
end