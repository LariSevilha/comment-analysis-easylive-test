require 'descriptive_statistics'

class MetricsService
  CACHE_TTL = 1.hour
  USER_METRICS_CACHE_KEY = 'user_metrics'
  GROUP_METRICS_CACHE_KEY = 'group_metrics'

  def self.calculate_user_metrics(user_id)
    new.calculate_user_metrics(user_id)
  end

  def self.calculate_group_metrics
    new.calculate_group_metrics
  end

  def self.recalculate_all_metrics
    new.recalculate_all_metrics
  end

  def calculate_user_metrics(user_id)
    CacheManager.fetch(user_id.to_s, cache_type: :user_metrics) do
      user = User.find(user_id)
      comments = user.comments.includes(:post)

      metrics_data = build_user_metrics_data(user, comments)
      update_user_metrics_record(user, metrics_data)

      metrics_data
    end
  end

  def calculate_group_metrics
    CacheManager.fetch('all', cache_type: :group_metrics) do
      all_comments = Comment.includes(post: :user)
      all_users = User.includes(:comments)

      metrics_data = build_group_metrics_data(all_comments, all_users)
      update_group_metrics_record(metrics_data)

      metrics_data
    end
  end

  def recalculate_all_metrics
    # Clear all metrics cache
    clear_metrics_cache

    # Recalculate metrics for all users
    User.find_each do |user|
      calculate_user_metrics(user.id)
    end

    # Recalculate group metrics
    calculate_group_metrics
  end

  private

  def build_user_metrics_data(user, comments)
    approved_comments = comments.select { |c| c.status == 'approved' }
    rejected_comments = comments.select { |c| c.status == 'rejected' }
    processing_comments = comments.select { |c| c.status == 'processing' }

    keyword_counts = comments.map { |c| c.keyword_count || 0 }
    approved_keyword_counts = approved_comments.map { |c| c.keyword_count || 0 }

    {
      user_id: user.id,
      user_name: user.name,
      total_comments: comments.count,
      approved_comments: approved_comments.count,
      rejected_comments: rejected_comments.count,
      processing_comments: processing_comments.count,
      avg_keyword_count: calculate_mean(keyword_counts),
      median_keyword_count: calculate_median(keyword_counts),
      std_dev_keyword_count: calculate_standard_deviation(keyword_counts),
      avg_approved_keyword_count: calculate_mean(approved_keyword_counts),
      median_approved_keyword_count: calculate_median(approved_keyword_counts),
      std_dev_approved_keyword_count: calculate_standard_deviation(approved_keyword_counts),
      approval_rate: calculate_approval_rate(approved_comments.count, comments.count),
      rejection_rate: calculate_rejection_rate(rejected_comments.count, comments.count),
      calculated_at: Time.current
    }
  end

  def build_group_metrics_data(all_comments, all_users)
    approved_comments = all_comments.select { |c| c.status == 'approved' }
    rejected_comments = all_comments.select { |c| c.status == 'rejected' }
    processing_comments = all_comments.select { |c| c.status == 'processing' }

    keyword_counts = all_comments.map { |c| c.keyword_count || 0 }
    approved_keyword_counts = approved_comments.map { |c| c.keyword_count || 0 }

    users_with_comments = all_users.select { |u| u.comments.any? }
    comments_per_user = users_with_comments.map { |u| u.comments.count }

    {
      total_users: all_users.count,
      users_with_comments: users_with_comments.count,
      total_comments: all_comments.count,
      approved_comments: approved_comments.count,
      rejected_comments: rejected_comments.count,
      processing_comments: processing_comments.count,
      avg_keyword_count: calculate_mean(keyword_counts),
      median_keyword_count: calculate_median(keyword_counts),
      std_dev_keyword_count: calculate_standard_deviation(keyword_counts),
      avg_approved_keyword_count: calculate_mean(approved_keyword_counts),
      median_approved_keyword_count: calculate_median(approved_keyword_counts),
      std_dev_approved_keyword_count: calculate_standard_deviation(approved_keyword_counts),
      avg_comments_per_user: calculate_mean(comments_per_user),
      median_comments_per_user: calculate_median(comments_per_user),
      std_dev_comments_per_user: calculate_standard_deviation(comments_per_user),
      approval_rate: calculate_approval_rate(approved_comments.count, all_comments.count),
      rejection_rate: calculate_rejection_rate(rejected_comments.count, all_comments.count),
      calculated_at: Time.current
    }
  end

  def update_user_metrics_record(user, metrics_data)
    user_metrics = user.user_metrics || user.build_user_metrics

    user_metrics.update!(
      total_comments: metrics_data[:total_comments],
      approved_comments: metrics_data[:approved_comments],
      rejected_comments: metrics_data[:rejected_comments],
      avg_keyword_count: metrics_data[:avg_keyword_count],
      median_keyword_count: metrics_data[:median_keyword_count],
      std_dev_keyword_count: metrics_data[:std_dev_keyword_count],
      calculated_at: metrics_data[:calculated_at]
    )
  end

  def update_group_metrics_record(metrics_data)
    group_metrics = GroupMetrics.current

    group_metrics.update!(
      total_users: metrics_data[:total_users],
      total_comments: metrics_data[:total_comments],
      approved_comments: metrics_data[:approved_comments],
      rejected_comments: metrics_data[:rejected_comments],
      avg_keyword_count: metrics_data[:avg_keyword_count],
      median_keyword_count: metrics_data[:median_keyword_count],
      std_dev_keyword_count: metrics_data[:std_dev_keyword_count],
      calculated_at: metrics_data[:calculated_at]
    )
  end

  def calculate_mean(values)
    return 0.0 if values.empty?
    values.mean.round(2)
  end

  def calculate_median(values)
    return 0.0 if values.empty?
    values.median.round(2)
  end

  def calculate_standard_deviation(values)
    return 0.0 if values.empty? || values.length < 2
    values.standard_deviation.round(2)
  end

  def calculate_approval_rate(approved_count, total_count)
    return 0.0 if total_count.zero?
    (approved_count.to_f / total_count * 100).round(2)
  end

  def calculate_rejection_rate(rejected_count, total_count)
    return 0.0 if total_count.zero?
    (rejected_count.to_f / total_count * 100).round(2)
  end

  def clear_metrics_cache
    # Use CacheManager's intelligent invalidation
    CacheManager.invalidate_related_caches(:metrics_recalculation)
  end
end
