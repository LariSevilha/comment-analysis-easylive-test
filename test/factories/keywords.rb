FactoryBot.define do
  factory :keyword do
    sequence(:word) { |n| "keyword#{n}" }

    trait :common_keywords do
      initialize_with { Keyword.find_or_create_by(word: word) }
    end
  end

  # Factory for creating a set of default keywords
  factory :keyword_set, class: Array do
    initialize_with do
      %w[importante relevante útil interessante valioso significativo].map do |word|
        Keyword.find_or_create_by(word: word)
      end
    end
  end
end
