class Keyword < ApplicationRecord
  validates :word, presence: true, uniqueness: true
  validates :word, length: { minimum: 2 }

  scope :active, -> { where(active: true) }

  after_create :invalidate_cache_and_reprocess
  after_update :invalidate_cache_and_reprocess, if: :saved_change_to_active?
  after_destroy :invalidate_cache_and_reprocess

  private

  def invalidate_cache_and_reprocess
    Rails.cache.delete('active_keywords')
    MetricsService.invalidate_cache 
    ReprocessAllCommentsJob.perform_later
  end
end