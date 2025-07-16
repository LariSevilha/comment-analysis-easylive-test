class UserMetric < ApplicationRecord
  belongs_to :user
  
  validates :metric_type, presence: true
  validates :value, presence: true, numericality: true
  
  scope :for_metric, ->(type) { where(metric_type: type) }
end