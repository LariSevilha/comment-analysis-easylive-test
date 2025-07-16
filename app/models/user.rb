class User < ApplicationRecord
  has_many :posts, dependent: :destroy
  has_many :comments, through: :posts
  has_one :user_metrics, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true
  validates :external_id, presence: true, uniqueness: true
end
