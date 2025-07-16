class ImportJob < ApplicationJob
  queue_as :default

  # Retry configuration for failed jobs
  retry_on ImportService::APIError, wait: :polynomially_longer, attempts: 3
  retry_on ImportService::UserNotFoundError, attempts: 1
  retry_on StandardError, wait: 5.seconds, attempts: 2

  # Discard job if user is not found after retries
  discard_on ImportService::UserNotFoundError do |job, error|
    Rails.logger.error "ImportJob discarded - User not found: #{error.message}"
    job_tracker_id = job.arguments.last
    begin
      job_tracker = JobTracker.find(job_tracker_id)
      job_tracker.update_progress(job_tracker.progress, error.message)
    rescue => e
      Rails.logger.error "Failed to update job tracker #{job_tracker_id}: #{e.message}"
    end
  end

  def perform(username, job_tracker_id)
    Rails.logger.info "Starting ImportJob for username: #{username}, job_tracker: #{job_tracker_id}"

    # Find the job tracker
    job_tracker = JobTracker.find(job_tracker_id)
    job_tracker.update!(status: :processing, progress: 0)

    begin
      # Initialize import service
      import_service = ImportService.new

      # Update progress: Starting import
      job_tracker.update_progress(10)

      # Import user and related data
      import_result = import_service.import_user_by_username(username)

      # Update progress: Import completed
      job_tracker.update_progress(50)

      # Get all new comments that need translation
      user = import_result[:user]
      new_comments = user.comments.where(status: :new)

      Rails.logger.info "Found #{new_comments.count} new comments to process for user: #{username}"

      # Update job tracker with total comments to process
      total_comments = new_comments.count
      job_tracker.update!(
        total: total_comments + 50, # 50 for import, rest for translation
        progress: 50,
        metadata: {
          username: username,
          user_id: user.id,
          posts_imported: import_result[:posts_count],
          comments_imported: import_result[:comments_count],
          comments_to_translate: total_comments
        }.to_json
      )

      # Queue translation jobs for each new comment
      if total_comments > 0
        new_comments.find_each.with_index do |comment, index|
          TranslationJob.perform_later(comment.id, job_tracker_id, index + 1, total_comments)
        end

        Rails.logger.info "Queued #{total_comments} TranslationJobs for user: #{username}"
      else
        # No comments to translate, mark as completed
        job_tracker.update_progress(job_tracker.total)
        Rails.logger.info "No new comments to translate for user: #{username}"
      end

      Rails.logger.info "ImportJob completed successfully for username: #{username}"

    rescue ImportService::ImportError => e
      Rails.logger.error "ImportJob failed for username: #{username} - #{e.message}"
      job_tracker.update_progress(job_tracker.progress, e)
      raise # Re-raise to trigger retry logic

    rescue => e
      Rails.logger.error "ImportJob failed with unexpected error for username: #{username} - #{e.message}"
      job_tracker.update_progress(job_tracker.progress, e)
      raise # Re-raise to trigger retry logic
    end
  end


end
