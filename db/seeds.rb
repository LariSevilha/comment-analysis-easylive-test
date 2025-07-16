keywords = [
  { word: "excelente", active: true, description: "Palavra muito positiva" },
  { word: "ótimo", active: true, description: "Palavra positiva" },
  { word: "bom", active: true, description: "Palavra positiva" },
  { word: "fantástico", active: true, description: "Palavra muito positiva" },
  { word: "perfeito", active: true, description: "Palavra positiva" },
  { word: "maravilhoso", active: true, description: "Palavra muito positiva" },
  { word: "incrível", active: true, description: "Palavra positiva" },
  { word: "amor", active: true, description: "Palavra positiva" },
  { word: "feliz", active: true, description: "Palavra positiva" },
  { word: "sucesso", active: true, description: "Palavra positiva" }
]

keywords.each do |keyword_attrs|
  Keyword.find_or_create_by(word: keyword_attrs[:word]) do |keyword|
    keyword.active = keyword_attrs[:active]
    keyword.description = keyword_attrs[:description]
  end
end

puts "#{keywords.count} keywords created!"

sample_user = User.find_or_create_by(username: 'Bret') do |user|
  user.name = 'Leanne Graham'
  user.email = 'Sincere@april.biz'
  user.external_id = 1 
end

puts "✅ Created sample user: #{sample_user.username}"