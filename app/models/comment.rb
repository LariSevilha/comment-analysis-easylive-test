class Comment < ApplicationRecord
  include AASM
  
  belongs_to :post
  
  validates :external_id, presence: true, uniqueness: true
  
  aasm column: :status do
    state :novo, initial: true
    state :processando
    state :aprovado
    state :rejeitado
    
    event :start_processing do
      transitions from: :novo, to: :processando
    end
    
    event :approve do
      transitions from: :processando, to: :aprovado
    end
    
    event :reject do
      transitions from: :processando, to: :rejeitado
    end
  end
  
  scope :processed, -> { where(status: ['aprovado', 'rejeitado']) }
  scope :approved, -> { where(status: 'aprovado') }
  scope :rejected, -> { where(status: 'rejeitado') }
  
  def analyze_keywords!
    return unless translated_body.present?
    
    active_keywords = Keyword.active.pluck(:word).map(&:downcase)
    translated_words = translated_body.downcase.split(/\W+/)
    
    matched = active_keywords.select { |keyword| translated_words.include?(keyword) }
    
    self.matched_keywords = matched
    self.matched_keywords_count = matched.size
    
    if matched_keywords_count >= 2
      approve!
    else
      reject!
    end
    
    save!
  end
end