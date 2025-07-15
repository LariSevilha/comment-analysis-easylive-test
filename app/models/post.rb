class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  
  validates :external_id, presence: true, uniqueness: true
end