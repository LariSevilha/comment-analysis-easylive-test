class Comment < ApplicationRecord
  include AASM
  
  belongs_to :post
  has_one :user, through: :post
  
  validates :body, presence: true
  validates :external_id, presence: true, uniqueness: true
  
  counter_cache :post
  
  aasm column: :status do
    state :new, initial: true
    state :processing
    state :approved
    state :rejected
    
    event :start_processing do
      transitions from: :new, to: :processing
    end
    
    event :approve do
      transitions from: :processing, to: :approved
      after do
        update_approval_metrics!
      end
    end
    
    event :reject do
      transitions from: :processing, to: :rejected
      after do
        update_rejection_metrics!
      end
    end
    
    event :reprocess do
      transitions from: [:approved, :rejected], to: :processing
    end
  end
  
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :processed, -> { where(status: ['approved', 'rejected']) }
  
  def process_classification!
    start_processing!
    CommentProcessingJob.perform_later(id)
  end
  
  private
  
  def update_approval_metrics!
    user.recalculate_metrics!
    GroupMetricsJob.perform_later
  end
  
  def update_rejection_metrics!
    user.recalculate_metrics!
    GroupMetricsJob.perform_later
  end
end
