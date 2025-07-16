class GroupMetrics < ApplicationRecord
  # Singleton model for global metrics
  validates :id, uniqueness: true

  def self.current
    first_or_create
  end

  def processing_comments
    total_comments - approved_comments - rejected_comments
  end

  def approval_rate
    return 0.0 if total_comments.zero?
    (approved_comments.to_f / total_comments * 100).round(2)
  end

  def rejection_rate
    return 0.0 if total_comments.zero?
    (rejected_comments.to_f / total_comments * 100).round(2)
  end

  def avg_comments_per_user
    return 0.0 if total_users.zero?
    (total_comments.to_f / total_users).round(2)
  end
end
