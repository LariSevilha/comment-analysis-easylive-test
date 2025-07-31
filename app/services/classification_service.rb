class ClassificationService
  # Configuration constants
  MINIMUM_KEYWORDS_FOR_APPROVAL = 2
  CACHE_EXPIRY = 30.minutes # Cache keywords for 30 minutes

  # Custom exceptions
  class ClassificationError < StandardError; end

  def initialize
    @keywords_cache = nil
    @keywords_cache_time = nil
  end 
  
  # Hardcoded keywords for classification
  KEYWORDS = %w[
    bom excelente ótimo perfeito maravilhoso fantástico incrível amor
  ].freeze

  # Main method to classify a comment based on keywords - CORRIGIDO
  def classify_comment(comment)
    raise ClassificationError, "Comment cannot be nil" if comment.nil?
    raise ClassificationError, "Comment must be persisted" unless comment.persisted?

    Rails.logger.info "Classifying comment #{comment.id} for user: #{comment.post.user.name}"

    begin
      # Get the text to analyze (prefer translated, fallback to original)
      text_to_analyze = get_text_for_analysis(comment)

      # Count keywords in the text
      keyword_count = count_keywords_in_text(text_to_analyze)

      # Update comment with keyword count
      comment.update!(keyword_count: keyword_count)

      # Determine approval based on keyword count
      should_approve = keyword_count >= MINIMUM_KEYWORDS_FOR_APPROVAL

      # Apply classification and update state
      apply_classification(comment, should_approve, keyword_count)

      Rails.logger.info "Comment #{comment.id} classified: #{should_approve ? 'approved' : 'rejected'} (#{keyword_count} keywords)"

      {
        approved: should_approve,
        keyword_count: keyword_count,
        status: comment.status
      }

    rescue => e
      Rails.logger.error "Classification failed for comment #{comment.id}: #{e.message}"

      # In case of error, reject the comment
      comment.reject! if comment.may_reject?

      raise ClassificationError, "Failed to classify comment: #{e.message}"
    end
  end

  # Batch classify multiple comments (more efficient for bulk operations)
  def classify_comments(comments)
    return [] if comments.blank?

    results = []
    comments.each do |comment|
      begin
        result = classify_comment(comment)
        results << { comment_id: comment.id, result: result }
      rescue ClassificationError => e
        Rails.logger.error "Failed to classify comment #{comment.id}: #{e.message}"
        results << { comment_id: comment.id, error: e.message }
      end
    end

    results
  end

  # Get current keyword count for a text without persisting
  def preview_classification(text)
    if text.blank?
      return {
        keyword_count: 0,
        would_approve: false
      }
    end

    keyword_count = count_keywords_in_text(text)

    {
      keyword_count: keyword_count,
      would_approve: keyword_count >= MINIMUM_KEYWORDS_FOR_APPROVAL
    }
  end

  # Reclassify all comments (useful when keywords change)
  def reclassify_all_comments
    Rails.logger.info "Starting reclassification of all comments"

    # Clear keywords cache to ensure fresh data
    clear_keywords_cache

    # Get all comments that have been processed
    comments_to_reclassify = Comment.where(status: [:approved, :rejected])
    total_comments = comments_to_reclassify.count

    Rails.logger.info "Reclassifying #{total_comments} comments"

    success_count = 0
    error_count = 0

    comments_to_reclassify.find_each.with_index do |comment, index|
      begin
        # Reset to processing state for reclassification
        comment.update!(status: :processing)

        # Classify the comment
        classify_comment(comment)
        success_count += 1

        # Log progress every 100 comments
        if (index + 1) % 100 == 0
          Rails.logger.info "Reclassification progress: #{index + 1}/#{total_comments} comments processed"
        end

      rescue => e
        Rails.logger.error "Failed to reclassify comment #{comment.id}: #{e.message}"
        error_count += 1
      end
    end

    Rails.logger.info "Reclassification completed: #{success_count} successful, #{error_count} errors"

    {
      total_processed: total_comments,
      successful: success_count,
      errors: error_count
    }
  end

  private

  # Get the text to analyze from comment (prefer translated, fallback to original) - CORRIGIDO
  def get_text_for_analysis(comment)
    # Prioriza translated_body se estiver presente, senão usa body original
    text = comment.translated_body.presence || comment.body

    if text.blank?
      raise ClassificationError, "Comment has no text to analyze"
    end

    Rails.logger.debug "Using text for analysis: #{text[0..50]}..." 
    text
  end

  # Count keywords in the given text (case-insensitive) - MELHORADO
  def count_keywords_in_text(text)
    return 0 if text.blank?

    # Use hardcoded keywords instead of database for consistency
    keywords = KEYWORDS
    return 0 if keywords.empty?

    # Normalize text for comparison (lowercase, remove extra spaces)
    normalized_text = text.downcase.strip

    # Count unique keywords found in text
    found_keywords = Set.new

    keywords.each do |keyword|
      normalized_keyword = keyword.downcase.strip

      # Check if keyword exists in text (word boundary matching for accuracy)
      if normalized_text.match?(/\b#{Regexp.escape(normalized_keyword)}\b/)
        found_keywords.add(normalized_keyword)
      end
    end

    if found_keywords.any?
      Rails.logger.debug "Found keywords in text: #{found_keywords.to_a.join(', ')}"
    else
      Rails.logger.debug "No keywords found in text: #{normalized_text[0..100]}..."
    end

    found_keywords.size
  end

  # Get current keywords from database with caching (fallback to hardcoded)
  def get_keywords
    # Try to get from database first
    begin
      # Check if cache is still valid
      if @keywords_cache && @keywords_cache_time &&
         (Time.current - @keywords_cache_time) < CACHE_EXPIRY.seconds
        Rails.logger.debug "Using cached keywords (#{@keywords_cache.size} keywords)"
        return @keywords_cache
      end

      # Fetch fresh keywords from database
      Rails.logger.debug "Fetching fresh keywords from database"
      db_keywords = Keyword.pluck(:word)
      
      if db_keywords.any?
        @keywords_cache = db_keywords
        @keywords_cache_time = Time.current
        Rails.logger.info "Loaded #{@keywords_cache.size} keywords from database"
        return @keywords_cache
      end
    rescue => e
      Rails.logger.warn "Failed to load keywords from database: #{e.message}, using hardcoded keywords"
    end

    # Fallback to hardcoded keywords
    Rails.logger.info "Using hardcoded keywords (#{KEYWORDS.size} keywords)"
    KEYWORDS
  end

  # Clear keywords cache (useful when keywords are updated)
  def clear_keywords_cache
    @keywords_cache = nil
    @keywords_cache_time = nil
    Rails.logger.debug "Keywords cache cleared"
  end

  # Apply classification result to comment and update state - MELHORADO
  def apply_classification(comment, should_approve, keyword_count)
    if should_approve
      if comment.may_approve?
        comment.approve!
        Rails.logger.debug "Comment #{comment.id} approved with #{keyword_count} keywords"
      else
        Rails.logger.warn "Comment #{comment.id} cannot be approved from current state: #{comment.status}"
        # If can't approve but should be approved, try to reject instead
        if comment.may_reject?
          comment.reject!
          Rails.logger.warn "Comment #{comment.id} rejected instead due to state transition limitation"
        end
      end
    else
      if comment.may_reject?
        comment.reject!
        Rails.logger.debug "Comment #{comment.id} rejected with #{keyword_count} keywords"
      else
        Rails.logger.warn "Comment #{comment.id} cannot be rejected from current state: #{comment.status}"
      end
    end
  end
end