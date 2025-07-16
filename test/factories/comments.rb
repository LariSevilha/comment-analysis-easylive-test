FactoryBot.define do
  factory :comment do
    association :post
    sequence(:name) { |n| "Commenter #{n}" }
    sequence(:email) { |n| "commenter#{n}@example.com" }
    sequence(:body) { |n| "This is comment #{n} with some content that might contain keywords." }
    sequence(:external_id) { |n| n }
    status { :new }

    trait :processing do
      status { :processing }
    end

    trait :approved do
      status { :approved }
      translated_body { "Este é um comentário traduzido com palavras-chave importantes." }
      keyword_count { 2 }
    end

    trait :rejected do
      status { :rejected }
      translated_body { "Este é um comentário traduzido sem palavras relevantes." }
      keyword_count { 0 }
    end

    trait :with_keywords do
      body { "This comment contains important and relevant keywords that should be detected." }
      translated_body { "Este comentário contém palavras-chave importantes e relevantes que devem ser detectadas." }
      keyword_count { 3 }
      status { :approved }
    end

    trait :without_keywords do
      body { "This is just a simple comment without any special terms." }
      translated_body { "Este é apenas um comentário simples sem termos especiais." }
      keyword_count { 0 }
      status { :rejected }
    end
  end
end
