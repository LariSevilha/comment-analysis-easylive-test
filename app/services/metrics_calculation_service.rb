class MetricsCalculationService
  METRIC_TYPES = %w[
    approval_rate
    rejection_rate
    avg_comments_per_user
    avg_keyword_matches
    median_keyword_matches
    std_dev_keyword_matches
    total_comments
    total_approved
    total_rejected
  ].freeze
  
  def self.calculate_user_metrics(user)
    comments = user.comments.processed
    return if comments.empty?
    
    metrics = {}
    
    # Basic rates
    total_comments = comments.count
    approved_count = comments.approved.count
    rejected_count = comments.rejected.count
    
    metrics['approval_rate'] = (approved_count.to_f / total_comments * 100).round(2)
    metrics['rejection_rate'] = (rejected_count.to_f / total_comments * 100).round(2)
    metrics['total_comments'] = total_comments
    metrics['total_approved'] = approved_count
    metrics['total_rejected'] = rejected_count
    
    # Keyword statistics
    keyword_matches = comments.pluck(:keyword_matches_count)
    if keyword_matches.any?
      metrics['avg_keyword_matches'] = keyword_matches.mean.round(2)
      metrics['median_keyword_matches'] = keyword_matches.median
      metrics['std_dev_keyword_matches'] = keyword_matches.standard_deviation.round(2)
    end
    
    # Save metrics
    metrics.each do |metric_type, value|
      UserMetric.find_or_create_by(
        user: user,
        metric_type: metric_type
      ).update!(value: value)
    end
    
    metrics
  end
  
  def self.calculate_group_metrics
    users = User.processed
    return if users.empty?
    
    metrics = {}
    
    # Aggregate all comments
    all_comments = Comment.joins(:post).where(posts: { user: users }).processed
    total_comments = all_comments.count
    approved_comments = all_comments.approved.count
    rejected_comments = all_comments.rejected.count
    
    metrics['approval_rate'] = (approved_comments.to_f / total_comments * 100).round(2)
    metrics['rejection_rate'] = (rejected_comments.to_f / total_comments * 100).round(2)
    metrics['avg_comments_per_user'] = (total_comments.to_f / users.count).round(2)
    metrics['total_comments'] = total_comments
    metrics['total_approved'] = approved_comments
    metrics['total_rejected'] = rejected_comments
    
    # Keyword statistics across all users
    keyword_matches = all_comments.pluck(:keyword_matches_count)
    if keyword_matches.any?
      metrics['avg_keyword_matches'] = keyword_matches.mean.round(2)
      metrics['median_keyword_matches'] = keyword_matches.median
      metrics['std_dev_keyword_matches'] = keyword_matches.standard_deviation.round(2)
    end
    
    # Save group metrics
    metrics.each do |metric_type, value|
      GroupMetric.create!(
        metric_type: metric_type,
        value: value,
        sample_size: users.count
      )
    end
    
    metrics
  end
end