class CommentProcessingJob < ApplicationJob
    queue_as :comment_processing
    
    def perform(comment_id)
      comment = Comment.find(comment_id)
      
      @processing_job.update!(
        progress_info: "Processing comment ID: #{comment_id}",
        total_items: 1,
        processed_items: 0
      )
      
      CommentClassificationService.classify_comment(comment)
      
      @processing_job.update!(
        processed_items: 1,
        progress_info: "Comment processed: #{comment.status}"
      )
    end
  end