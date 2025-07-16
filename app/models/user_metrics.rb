class UserMetrics < ApplicationRecord
  belongs_to :user

  validates :user_id, uniqueness: true

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
end
