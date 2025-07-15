keywords = [
  'excelente', 'ótimo', 'bom', 'fantástico', 'maravilhoso',
  'péssimo', 'ruim', 'terrível', 'horrível', 'incrível',
  'amor', 'feliz', 'triste', 'raiva', 'alegria',
  'problema', 'solução', 'ajuda', 'suporte', 'qualidade'
]

keywords.each do |word|
  Keyword.find_or_create_by(word: word) do |keyword|
    keyword.active = true
  end
end

puts "✅ Created #{keywords.count} keywords"

sample_user = User.find_or_create_by(username: 'Bret') do |user|
  user.name = 'Leanne Graham'
  user.email = 'Sincere@april.biz'
  user.external_id = 1 
end

puts "✅ Created sample user: #{sample_user.username}"