class Keyword < ApplicationRecord
  validates :word, presence: true, uniqueness: { case_sensitive: false }
  
  before_save :normalize_word
  after_create :reprocess_all_comments
  after_update :reprocess_all_comments
  after_destroy :reprocess_all_comments
  
  scope :active, -> { where(active: true) }
  
  private
  
  def normalize_word
    self.word = word.strip.downcase
  end
  
  def reprocess_all_comments
    Rails.cache.delete('active_keywords')
    ReprocessAllCommentsJob.perform_now
  end
end