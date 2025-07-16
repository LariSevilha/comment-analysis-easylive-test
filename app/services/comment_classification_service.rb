class CommentClassificationService
    def self.classify_comment(comment)
      keywords = active_keywords
      translated_text = TranslationService.translate_to_portuguese(comment.body)
      
      comment.update!(translated_body: translated_text)
      
      matches = count_keyword_matches(translated_text, keywords)
      comment.update!(keyword_matches_count: matches)
      
      if matches >= 2
        comment.approve!
      else
        comment.reject!
      end
      
      comment.update!(processed: Time.current)
    end
    
    private
    
    def self.active_keywords
      Rails.cache.fetch('active_keywords', expires_in: 1.hour) do
        Keyword.active.pluck(:word)
      end
    end
    
    def self.count_keyword_matches(text, keywords)
      normalized_text = text.downcase
      keywords.count { |keyword| normalized_text.include?(keyword.downcase) }
    end
  end
  