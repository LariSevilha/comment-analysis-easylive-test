puts "🌱 Seeding database..."

# Default keywords for comment classification
default_keywords = [
  "bom", "boa", "excelente", "ótimo", "ótima", "perfeito", "perfeita",
  "maravilhoso", "maravilhosa", "fantástico", "fantástica", "incrível",
  "amor", "amei", "adorei", "gostei", "legal", "bacana", "show",
  "qualidade", "profissional", "eficiente", "rápido", "rápida",
  "confiável", "seguro", "segura", "recomendo", "recomendado",
  "interessante", "útil", "importante", "necessário", "necessária",
  "valor", "benefício", "vantagem", "solução", "resultado",
  "funciona", "funcionou", "resolveu", "ajudou", "melhorou",
  "facilitou", "otimizou", "economizou", "ganhou", "conquistou"
]

puts "Creating default keywords..."
created_count = 0
existing_count = 0

# Temporarily disable background job triggers during seeding
original_perform_enqueued_jobs = ActiveJob::Base.queue_adapter.perform_enqueued_jobs rescue nil
ActiveJob::Base.queue_adapter = :test if Rails.env.development?

default_keywords.each do |word|
  keyword = Keyword.find_or_initialize_by(word: word.downcase.strip)
  if keyword.new_record?
    keyword.save!
    created_count += 1
    puts "  ✓ Created keyword: #{word}"
  else
    existing_count += 1
    puts "  - Keyword already exists: #{word}"
  end
end

# Criar usuário de teste
puts "\nCreating sample user..."
sample_user = User.find_or_create_by(username: 'testuser') do |user|
  user.name = 'Test User'
  user.email = 'test@example.com'
  user.external_id = '999' # Deve ser string, conforme schema
end
puts "  ✓ Sample user: #{sample_user.username} (ID: #{sample_user.id})"

# Criar post de exemplo
puts "Creating sample post..."
sample_post = Post.find_or_create_by(external_id: '999') do |post|
  post.title = 'Sample Post'
  post.body = 'This is a sample post for testing comment analysis and translation'
  post.user = sample_user
end
puts "  ✓ Sample post: #{sample_post.title} (ID: #{sample_post.id})"

# Criar comentários de exemplo
puts "Creating sample comments..."
comments_data = [
  {
    name: "Positive Commenter",
    email: "positive@test.com",
    body: "This product is excellent and fantastic! I love it and think it's perfect.",
    external_id: "comment_1",
    status: "processing"
  },
  {
    name: "Latin Commenter",
    email: "latin@test.com",
    body: "Lorem ipsum dolor sit amet consectetur adipiscing elit laudantium enim quasi",
    external_id: "comment_2",
    status: "processing"
  },
  {
    name: "Neutral Commenter",
    email: "neutral@test.com",
    body: "This is just a regular comment without special keywords",
    external_id: "comment_3",
    status: "processing"
  },
  {
    name: "Mixed Commenter",
    email: "mixed@test.com",
    body: "The service was good but could be better. Overall satisfactory experience.",
    external_id: "comment_4",
    status: "processing"
  }
]

created_comments_count = 0
comments_data.each do |comment_data|
  comment = Comment.find_or_create_by(external_id: comment_data[:external_id]) do |c|
    c.name = comment_data[:name]
    c.email = comment_data[:email]
    c.body = comment_data[:body]
    c.status = comment_data[:status]
    c.post = sample_post
  end
  if comment.persisted?
    created_comments_count += 1
    puts "  ✓ Comment: ID #{comment.id} - #{comment.body[0..40]}..."
  else
    puts "  ✗ Failed to create comment: #{comment_data[:body][0..40]}..."
  end
end

# Restore original queue adapter
ActiveJob::Base.queue_adapter = :solid_queue if Rails.env.development?

puts "\n📊 Seeding completed!"
puts "  • #{created_count} new keywords created"
puts "  • #{existing_count} keywords already existed"
puts "  • Total keywords in database: #{Keyword.count}"
puts "  • Sample user created: #{sample_user.username}"
puts "  • Sample post created: #{sample_post.title}"
puts "  • #{created_comments_count} sample comments created"

puts "\n🎯 Ready for testing!"
puts "  • Use username: '#{sample_user.username}' for analysis"
puts "  • Comment IDs for translation: #{Comment.where(post: sample_post).pluck(:id).join(', ')}"
puts "  • Keywords classification: >= 2 keywords → APPROVED, < 2 keywords → REJECTED"