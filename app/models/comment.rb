class Comment < ApplicationRecord
  include AASM

  belongs_to :post
  has_one :user, through: :post

  validates :name, presence: true
  validates :email, presence: true
  validates :body, presence: true
  validates :external_id, presence: true, uniqueness: true

  aasm column: 'status' do
    state :new, initial: true
    state :processing
    state :approved
    state :rejected

    event :start_processing do
      transitions from: :new, to: :processing,
                  guard: :can_start_processing?,
                  after: :log_processing_started
    end

    event :approve do
      transitions from: :processing, to: :approved,
                  guard: :can_approve?,
                  after: :log_approval
    end

    event :reject do
      transitions from: :processing, to: :rejected,
                  guard: :can_reject?,
                  after: :log_rejection
    end
  end

  private

  # Guards for state transitions
  def can_start_processing?
    body.present? && name.present? && email.present?
  end

  def can_approve?
    translated_body.present? || body.present?
  end

  def can_reject?
    true # Can always reject from processing state
  end

  # Callbacks for logging state changes
  def log_processing_started
    Rails.logger.info "Comment #{id} started processing - User: #{post.user.name}, Post: #{post.id}"
  end

  def log_approval
    Rails.logger.info "Comment #{id} approved - Keyword count: #{keyword_count || 0}, User: #{post.user.name}"
  end

  def log_rejection
    Rails.logger.info "Comment #{id} rejected - Keyword count: #{keyword_count || 0}, User: #{post.user.name}"
  end
end
