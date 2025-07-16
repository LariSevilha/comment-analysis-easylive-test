class AnalysisJob < ApplicationRecord
  validates :job_type, presence: true

  enum :status, { pending: 0, running: 1, completed: 2, failed: 3 }, default: :pending

  scope :recent, -> { order(created_at: :desc) }
end