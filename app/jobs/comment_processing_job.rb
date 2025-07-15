class CommentProcessingJob < ApplicationJob
    def perform(comment_id)
      comment = Comment.find(comment_id)
      CommentProcessingService.new(comment).process!
    end
  end