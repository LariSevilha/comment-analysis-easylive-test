class AnalysisJob < ApplicationRecord
    validates :job_type, presence: true
    
    scope :pending, -> { where(status: 'pending') }
    scope :processing, -> { where(status: 'processing') }
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    
    def progress_percentage
      return 0 if total_items.zero?
      ((processed_items.to_f / total_items) * 100).round(2)
    end
    
    def start!
      update!(status: 'processing', started_at: Time.current)
    end
    
    def complete!
      update!(status: 'completed', completed_at: Time.current)
    end
    
    def fail!(error_msg)
      update!(status: 'failed', error_message: error_msg, completed_at: Time.current)
    end
    
    def increment_progress!
      increment!(:processed_items)
    end
  end