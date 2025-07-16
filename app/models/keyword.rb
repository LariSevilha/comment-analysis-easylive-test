class Keyword < ApplicationRecord
  validates :word, presence: true, uniqueness: { case_sensitive: false }

  before_save :normalize_word

  after_save :trigger_recalculation
  after_destroy :trigger_recalculation

  private

  def normalize_word
    self.word = word.downcase.strip if word.present?
  end

  def trigger_recalculation
    Rails.logger.info "Keyword #{word} changed, triggering metrics recalculation"
    CacheManager.invalidate_related_caches(:keyword_change)
    MetricsRecalculationJob.trigger_keyword_change_recalculation
  end
end
