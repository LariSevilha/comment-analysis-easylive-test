class GroupMetric < ApplicationRecord
    validates :metric_type, presence: true
    validates :value, presence: true, numericality: true
    
    scope :for_metric, ->(type) { where(metric_type: type) }
    scope :latest, -> { order(created_at: :desc) }
  end