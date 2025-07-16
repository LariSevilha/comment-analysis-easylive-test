class ReprocessAllCommentsJob < ApplicationJob
    queue_as :reprocessing
    
    def perform
      comments = Comment.processed
      
      @processing_job.update!(
        progress_info: "Reprocessing all comments due to keyword changes",
        total_items: comments.count,
        processed_items: 0
      )
      
      comments.find_each.with_index do |comment, index|
        comment.reprocess!
        CommentProcessingJob.perform_async(comment.id)
        
        @processing_job.update!(
          processed_items: index + 1,
          progress_info: "Reprocessed #{index + 1}/#{comments.count} comments"
        )
      end
      
      # Recalculate all metrics after reprocessing
      User.processed.find_each do |user|
        UserMetricsJob.perform_async(user.id)
      end
      
      GroupMetricsJob.perform_async
    end
  end