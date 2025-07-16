class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  
  validates :title, presence: true
  validates :body, presence: true
  validates :external_id, presence: true, uniqueness: true
  
  counter_cache :comments_count
end