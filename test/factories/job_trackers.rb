FactoryBot.define do
  factory :job_tracker do
    sequence(:job_id) { |n| "job_#{n}_#{SecureRandom.uuid}" }
    status { :pending }
    progress { 0 }
    total { 100 }
    metadata { {} }

    trait :processing do
      status { :processing }
      progress { 50 }
    end

    trait :completed do
      status { :completed }
      progress { 100 }
    end

    trait :failed do
      status { :failed }
      error_message { "Job failed due to external API error" }
    end

    trait :with_import_metadata do
      metadata do
        {
          username: "testuser",
          imported_users: 1,
          imported_posts: 3,
          imported_comments: 15
        }
      end
    end
  end
end
