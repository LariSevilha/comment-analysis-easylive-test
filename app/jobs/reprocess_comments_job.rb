# app/jobs/reprocess_comments_job.rb
class ReprocessCommentsJob < ApplicationJob
    queue_as :default
  
    def perform(job_tracker_id)
      job_tracker = JobTracker.find(job_tracker_id)
      
      begin
        job_tracker.update!(status: 'processing')
        
        comments = Comment.all
        total_comments = comments.count
        
        Rails.logger.info "Starting reprocessing of #{total_comments} comments"
        
        translation_service = TranslationService.new
        classification_service = ClassificationService.new
        
        comments.each_with_index do |comment, index|
          begin
            Rails.logger.info "Reprocessing comment #{comment.id} (#{index + 1}/#{total_comments})"
            
            # Reset comment state
            comment.update!(
              status: 'processing', 
              translated_body: nil, 
              keyword_count: 0
            )
            
            # Detect source language
            source_language = detect_comment_language(comment.body)
            
            # Translate the comment
            translated_text = translation_service.translate(
              comment.body, 
              from: source_language, 
              to: 'pt'
            )
            
            # Save translation
            comment.update!(translated_body: translated_text)
            
            # Classify the comment
            classification_result = classification_service.classify_comment(comment)
            
            Rails.logger.info "Comment #{comment.id} reprocessed: #{classification_result[:approved] ? 'approved' : 'rejected'} (#{classification_result[:keyword_count]} keywords)"
            
            # Update progress
            progress = ((index + 1).to_f / total_comments * 100).round
            job_tracker.update!(progress: progress)
            
          rescue => e
            Rails.logger.error "Failed to reprocess comment #{comment.id}: #{e.message}"
            # Reject comment on error
            comment.update!(status: 'rejected') rescue nil
          end
        end
        
        # Complete the job
        job_tracker.update!(
          status: 'completed',
          progress: 100
        )
        
        Rails.logger.info "Reprocessing completed successfully"
        
      rescue => e
        Rails.logger.error "Reprocessing job failed: #{e.message}"
        job_tracker.update!(
          status: 'failed',
          error_message: e.message
        )
        raise
      end
    end
    
    private
    
    def detect_comment_language(text)
      # Simple language detection based on content patterns
      if text.match?(/lorem|ipsum|dolor|consectetur|adipiscing|elit|laudantium|sapiente/i)
        'la' # Latin
      elsif text.match?(/the|is|and|this|that|with|for|excellent|fantastic|perfect/i)
        'en' # English  
      else
        'en' # Default to English
      end
    end
  end