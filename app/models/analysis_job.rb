class AnalysisJob < ApplicationRecord
  # Define enum using Rails 8.0 syntax
  enum :status, {
    pending: 'pending',
    running: 'running',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending'

  validates :job_type, presence: true
  validates :status, presence: true

  store :metadata, coder: JSON

  def update_progress(processed, total, message = nil)
    percentage = total > 0 ? (processed.to_f / total * 100).round(2) : 0

    update!(
      processed_items: processed,
      total_items: total,
      progress_percentage: percentage,
      metadata: metadata.merge(current_step: message).compact
    )
  end

  def mark_as_running!
    update!(status: :running, started_at: Time.current)
  end

  def mark_as_completed!
    update!(
      status: :completed,
      completed_at: Time.current,
      progress_percentage: 100.0
    )
  end

  def mark_as_failed!(error_message)
    update!(
      status: :failed,
      error_message: error_message,
      completed_at: Time.current
    )
  end
end