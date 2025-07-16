FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:external_id) { |n| n }

    trait :with_posts do
      after(:create) do |user|
        create_list(:post, 3, user: user)
      end
    end

    trait :with_posts_and_comments do
      after(:create) do |user|
        posts = create_list(:post, 2, user: user)
        posts.each do |post|
          create_list(:comment, 5, post: post)
        end
      end
    end
  end
end
