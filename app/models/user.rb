class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :user_metrics, dependent: :destroy

  validates :username, presence: true, uniqueness: true
  validates :external_id, presence: true, uniqueness: true

  scope :analyzed, -> { where.not(processed: nil) }

  def approval_rate
    return 0.0 if comments_count.zero?
    (approved_comments_count.to_f / comments_count * 100).round(2)
  end

  def calculate_metrics!
    user_comments = comments.processed
    if user_comments.any?
      keyword_counts = user_comments.pluck(:keyword_matches_count).compact

      self.analysis_metrics = {
        total_comments: comments_count,
        approved_comments: approved_comments_count,
        rejected_comments: rejected_comments_count,
        approval_rate: approval_rate,
        keywords_stats: keyword_counts.any? ? {
          mean: keyword_counts.mean.round(2),
          median: keyword_counts.median.round(2),
          standard_deviation: keyword_counts.standard_deviation.round(2),
          variance: keyword_counts.variance.round(2),
          min: keyword_counts.min || 0,
          max: keyword_counts.max || 0
        } : {}
      }
    else
      self.analysis_metrics = {}
    end

    self.processed = Time.current
    save!
  end

  def analyzed?
    processed.present?
  end
end
