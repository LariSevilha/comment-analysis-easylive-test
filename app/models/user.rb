class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :comments, through: :posts
  
  validates :username, presence: true, uniqueness: true
  
  scope :analyzed, -> { where.not(last_analyzed_at: nil) }
  
  def approval_rate
    return 0 if total_comments.zero?
    (approved_comments.to_f / total_comments * 100).round(2)
  end
  
  def calculate_metrics!
    user_comments = comments.where(status: ['aprovado', 'rejeitado'])
    
    if user_comments.any?
      keyword_counts = user_comments.pluck(:matched_keywords_count)
      
      self.analysis_metrics = {
        total_comments: user_comments.count,
        approved_comments: user_comments.where(status: 'aprovado').count,
        rejected_comments: user_comments.where(status: 'rejeitado').count,
        approval_rate: approval_rate,
        keywords_stats: {
          mean: keyword_counts.mean.round(2),
          median: keyword_counts.median.round(2),
          standard_deviation: keyword_counts.standard_deviation.round(2),
          variance: keyword_counts.variance.round(2),
          min: keyword_counts.min,
          max: keyword_counts.max
        }
      }
    else
      self.analysis_metrics = {}
    end
    
    self.last_analyzed_at = Time.current
    save!
  end
end