class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :comments, through: :posts
  has_many :user_metrics, dependent: :destroy
  
  validates :username, presence: true, uniqueness: true
  validates :external_id, presence: true, uniqueness: true
  
  scope :processed, -> { where.not(processed: nil) }
  
  def recalculate_metrics!
    UserMetricsJob.perform_later(id)
  end
  
  def approved_comments_count
    comments.approved.count
  end
  
  def rejected_comments_count
    comments.rejected.count
  end
  
  def total_comments_count
    comments.count
  end
end
