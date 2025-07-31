class TranslationJob < ApplicationJob
  queue_as :default

  # Retry configuration for failed jobs
  retry_on TranslationService::APIError, wait: :polynomially_longer, attempts: 3
  retry_on TranslationService::RateLimitError, wait: 30.seconds, attempts: 5
  retry_on ActiveRecord::RecordNotFound, wait: 5.seconds, attempts: 2

  # Discard job after all retries are exhausted
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error "TranslationJob discarded - Deserialization error: #{error.message}"
  end

  def perform(comment_id, job_tracker_id, comment_index = nil, total_comments = nil, source_language: 'en')
    Rails.logger.info "Starting TranslationJob for comment: #{comment_id}, job_tracker: #{job_tracker_id}, source_language: #{source_language}"

    # Find the comment and job tracker
    comment = Comment.find(comment_id)
    job_tracker = JobTracker.find(job_tracker_id)

    begin
      # Transition comment to processing state
      if comment.may_start_processing?
        comment.start_processing!
        Rails.logger.debug "Comment #{comment_id} transitioned to processing state"
      else
        Rails.logger.warn "Comment #{comment_id} cannot transition to processing from state: #{comment.status}"
      end

      # Initialize services
      translation_service = TranslationService.new
      classification_service = ClassificationService.new

      # ETAPA 1: Traduzir o comentário
      Rails.logger.debug "Translating comment #{comment_id}: #{comment.body[0..50]}..."
      
      translated_text = translation_service.translate(
        comment.body, 
        from: source_language, 
        to: 'pt'
      )

      # CRITICAL: Update comment with translated text BEFORE classification
      comment.update!(translated_body: translated_text)
      Rails.logger.debug "Translation completed and saved for comment #{comment_id}: #{translated_text[0..50]}..."

      # ETAPA 2: Classificar o comentário (agora com translated_body populado)
      Rails.logger.debug "Classifying comment #{comment_id} with translated text"
      classification_result = classification_service.classify_comment(comment)

      Rails.logger.info "Comment #{comment_id} processed: #{classification_result[:approved] ? 'approved' : 'rejected'} (#{classification_result[:keyword_count]} keywords)"

      # Update job tracker progress if we have the index information
      if comment_index && total_comments && job_tracker
        update_translation_progress(job_tracker, comment_index, total_comments)
      end

      # Check if this was the last comment for this job
      if comment_index && total_comments && comment_index >= total_comments
        Rails.logger.info "All translations completed for job_tracker: #{job_tracker_id}"

        # Trigger metrics recalculation for the user
        user_id = comment.post.user.id
        MetricsRecalculationJob.perform_later(user_id, 'user_import_completed')
      end

    rescue TranslationService::TranslationError => e
      Rails.logger.error "TranslationJob failed for comment #{comment_id}: #{e.message}"

      # If translation fails, we still try to classify with original text
      begin
        Rails.logger.warn "Translation failed, attempting classification with original text"
        classification_service = ClassificationService.new
        classification_result = classification_service.classify_comment(comment)
        Rails.logger.info "Comment #{comment_id} classified with original text: #{classification_result[:approved] ? 'approved' : 'rejected'}"

        # Update progress even if translation failed
        if comment_index && total_comments && job_tracker
          update_translation_progress(job_tracker, comment_index, total_comments)
        end
      rescue => classification_error
        Rails.logger.error "Classification also failed for comment #{comment_id}: #{classification_error.message}"
        # Reject the comment if both translation and classification fail
        comment.reject! if comment.may_reject?
        raise # Re-raise to trigger retry logic
      end

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "TranslationJob failed - Comment or JobTracker not found: #{e.message}"
      raise # Re-raise to trigger retry logic

    rescue => e
      # Handle unexpected errors
      Rails.logger.error "TranslationJob failed with unexpected error for comment #{comment_id}: #{e.message}"
      Rails.logger.error "Error backtrace: #{e.backtrace.first(5).join("\n")}"

      # Reject the comment on unexpected errors
      begin
        comment.reject! if comment.may_reject?
      rescue => reject_error
        Rails.logger.error "Failed to reject comment #{comment_id}: #{reject_error.message}"
      end
      
      raise # Re-raise to trigger retry logic
    end
  end

  private

  def update_translation_progress(job_tracker, comment_index, total_comments)
    # Calculate progress: 50 points for import + proportional points for translation
    import_progress = 50
    translation_progress = (comment_index.to_f / total_comments * 50).round
    total_progress = import_progress + translation_progress
  
    job_tracker.update!(progress: [total_progress, job_tracker.total].min)
  
    Rails.logger.debug "Translation progress updated: #{comment_index}/#{total_comments} comments (#{total_progress}/#{job_tracker.total})"
  rescue => e
    Rails.logger.error "Failed to update translation progress for job_tracker #{job_tracker.id}: #{e.message}"
  end
end