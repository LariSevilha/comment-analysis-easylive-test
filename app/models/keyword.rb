class Keyword < ApplicationRecord
  validates :word, presence: true, uniqueness: true
  
  scope :active, -> { where(active: true) }
  
  after_commit :recalculate_all_users, on: [:create, :update, :destroy]
  
  private
  
  def recalculate_all_users
    RecalculateAllUsersJob.perform_later
  end
end
