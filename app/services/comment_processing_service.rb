class CommentProcessingService
    def initialize(comment)
      @comment = comment
    end
    
    def process!
      return unless @comment.novo?
      
      @comment.start_processing!
      
      # Translate comment
      translated_text = TranslationService.translate_to_portuguese(@comment.body)
      @comment.update!(translated_body: translated_text)
      
      # Analyze keywords and update status
      @comment.analyze_keywords!
      
      # Update user counters
      update_user_counters
      
      @comment
    end
    
    private
    
    def update_user_counters
      user = @comment.post.user
      processed_comments = user.comments.processed
      
      user.update!(
        total_comments: processed_comments.count,
        approved_comments: processed_comments.approved.count,
        rejected_comments: processed_comments.rejected.count
      )
    end
  end