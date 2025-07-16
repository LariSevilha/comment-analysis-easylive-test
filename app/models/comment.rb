 class Comment < ApplicationRecord
  include AASM

  belongs_to :post
  belongs_to :user 

  validates :external_id, presence: true, uniqueness: true
  validates :body, presence: true
  
  scope :processed, -> { where(status: ['approved', 'rejected']) }

  aasm column: :status do
    state :pending, initial: true
    state :processing
    state :approved
    state :rejected

    event :start_processing do
      transitions from: :pending, to: :processing
    end

    event :approve do
      transitions from: :processing, to: :approved
      after do
        increment_approved_count
      end
    end

    event :reject do
      transitions from: :processing, to: :rejected
      after do
        increment_rejected_count
      end
    end
  end

  def matched_keywords_count
    keyword_matches_count || 0
  end

  def process_comment!
    return unless may_start_processing?
    
    start_processing!
    
    # Traduzir comentário
    translated_text = TranslationService.translate(body)
    update!(translated_body: translated_text)
    
    # Contar palavras-chave
    keyword_count = count_keywords(translated_text)
    update!(keyword_matches_count: keyword_count)
    
    # Aprovar se >= 2 palavras-chave
    if keyword_count >= 2
      approve!
    else
      reject!
    end
    
    update!(processed: Time.current)
  end

  private

  def count_keywords(text)
    return 0 if text.blank?
    
    active_keywords = Rails.cache.fetch('active_keywords', expires_in: 1.hour) do
      Keyword.active.pluck(:word)
    end
    
    text_downcase = text.downcase
    active_keywords.count { |keyword| text_downcase.include?(keyword.downcase) }
  end

  def increment_approved_count
    user.increment!(:approved_comments_count)
    user.increment!(:comments_count) if user.comments_count.zero?
  end

  def increment_rejected_count
    user.increment!(:rejected_comments_count)
    user.increment!(:comments_count) if user.comments_count.zero?
  end
end