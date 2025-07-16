# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Default keywords for comment classification
# These keywords are used to classify comments as approved (>= 2 keywords) or rejected (< 2 keywords)
default_keywords = [
  # Positive sentiment words
  "bom", "boa", "excelente", "ótimo", "ótima", "perfeito", "perfeita",
  "maravilhoso", "maravilhosa", "fantástico", "fantástica", "incrível",
  "amor", "amei", "adorei", "gostei", "legal", "bacana", "show",

  # Quality indicators
  "qualidade", "profissional", "eficiente", "rápido", "rápida",
  "confiável", "seguro", "segura", "recomendo", "recomendado",

  # Engagement words
  "interessante", "útil", "importante", "necessário", "necessária",
  "valor", "benefício", "vantagem", "solução", "resultado",

  # Positive actions
  "funciona", "funcionou", "resolveu", "ajudou", "melhorou",
  "facilitou", "otimizou", "economizou", "ganhou", "conquistou"
]

puts "Creating default keywords..."
created_count = 0
existing_count = 0

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

puts "\n📊 Seeding completed!"
puts "  • #{created_count} new keywords created"
puts "  • #{existing_count} keywords already existed"
puts "  • Total keywords in database: #{Keyword.count}"
puts "\n🎯 Keywords are used for comment classification:"
puts "  • Comments with >= 2 keywords → APPROVED"
puts "  • Comments with < 2 keywords → REJECTED"
