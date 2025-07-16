require 'descriptive_statistics'

class MetricsService
  def self.group_metrics
    Rails.cache.fetch('group_metrics', expires_in: 1.hour) do
      calculate_group_metrics
    end
  end

  def self.invalidate_cache
    Rails.cache.delete('group_metrics')
    Rails.cache.delete('active_keywords')
    Rails.cache.write('group_metrics_last_updated', Time.current)
  end

  private

  def self.calculate_group_metrics
    users = User.analyzed
    return {} if users.empty?

    # Collect all approval rates
    approval_rates = users.map(&:approval_rate).compact
    
    # Collect all keyword counts from processed comments
    all_keyword_counts = Comment.processed.pluck(:keyword_matches_count).compact
    
    # Collect user-level metrics
    user_metrics = users.map { |user| user.analysis_metrics }.compact
    
    total_comments = user_metrics.sum { |m| m['total_comments'] || 0 }
    total_approved = user_metrics.sum { |m| m['approved_comments'] || 0 }
    total_rejected = user_metrics.sum { |m| m['rejected_comments'] || 0 }

    {
      total_users_analyzed: users.count,
      total_comments_processed: total_comments,
      total_approved_comments: total_approved,
      total_rejected_comments: total_rejected,
      overall_approval_rate: total_comments > 0 ? (total_approved.to_f / total_comments * 100).round(2) : 0.0,
      
      approval_rates_stats: calculate_stats(approval_rates),
      keyword_counts_stats: calculate_stats(all_keyword_counts),
      
      distribution: {
        users_by_approval_rate: {
          high: users.count { |u| u.approval_rate >= 70 },
          medium: users.count { |u| u.approval_rate >= 30 && u.approval_rate < 70 },
          low: users.count { |u| u.approval_rate < 30 }
        },
        comments_by_keyword_count: {
          high: all_keyword_counts.count { |c| c >= 3 },
          medium: all_keyword_counts.count { |c| c >= 1 && c < 3 },
          none: all_keyword_counts.count { |c| c == 0 }
        }
      },
      
      top_performers: users.order(approved_comments_count: :desc).limit(5).map do |user|
        {
          username: user.username,
          approval_rate: user.approval_rate,
          total_comments: user.comments_count,
          approved_comments: user.approved_comments_count
        }
      end,
      
      generated_at: Time.current
    }
  end

  def self.calculate_stats(values)
    return { count: 0 } if values.empty?

    {
      mean: values.mean.round(2),
      median: values.median.round(2),
      standard_deviation: values.standard_deviation.round(2),
      variance: values.variance.round(2),
      min: values.min || 0,
      max: values.max || 0,
      count: values.count
    }
  end
end