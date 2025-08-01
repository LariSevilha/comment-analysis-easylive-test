class JobTracker < ApplicationRecord
  validates :job_id, presence: true, uniqueness: true
  validates :job_type, presence: true
  validates :status, presence: true
  validates :progress, numericality: { greater_than_or_equal_to: 0 }
  validates :total, numericality: { greater_than_or_equal_to: 0 }

  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }

  def progress_percentage
    return 0 if total.zero?
    (progress.to_f / total * 100).round(2)
  end

  def update_progress(current_progress, error = nil)
    if error
      update!(
        progress: current_progress,
        status: :failed,
        error_message: error.to_s
      )
    else
      new_status = current_progress >= total ? :completed : :processing
      update!(
        progress: current_progress,
        status: new_status
      )
    end
  end
end