FactoryBot.define do
  factory :post do
    association :user
    sequence(:title) { |n| "Post Title #{n}" }
    sequence(:body) { |n| "This is the body content for post #{n}. It contains some meaningful text." }
    sequence(:external_id) { |n| n }

    trait :with_comments do
      after(:create) do |post|
        create_list(:comment, 5, post: post)
      end
    end
  end
end
