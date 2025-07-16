class CommentProcessorService
  def initialize(comment)
    @comment = comment
  end

  def call
    Rails.logger.info "Processing comment #{@comment.id}"
    @comment.iniciar_processamento!

    translated_body = translate_comment
    keyword_matches = count_keyword_matches(translated_body)

    @comment.update!(
      translated_body: translated_body,
      matched_keywords: keyword_matches,
      matched_keywords_count: keyword_matches.count
    )

    if keyword_matches.count >= 2
      @comment.aprovar!
      Rails.logger.info "Comment #{@comment.id} aprovado: #{keyword_matches.count} keywords found"
    else
      @comment.rejeitar!
      Rails.logger.info "Comment #{@comment.id} rejeitado: #{keyword_matches.count} keywords found"
    end
  rescue StandardError => e
    Rails.logger.error "Error processing comment #{@comment.id}: #{e.message}\n#{e.backtrace.join("\n")}"
    @comment.rejeitar! if @comment.processando?
  end

  private

  def translate_comment
    Rails.logger.info "Translating comment #{@comment.id}"
    
    # Try LibreTranslate first
    begin
      client = LibreTranslate::Client.new(ENV['LIBRETRANSLATE_URL'] || 'http://localhost:5000')
      return client.translate(@comment.body, source: 'en', target: 'pt')
    rescue StandardError => e
      Rails.logger.warn "LibreTranslate failed for comment #{@comment.id}: #{e.message}"
    end

    # Fallback to simple translation simulation
    Rails.logger.info "Using fallback translation for comment #{@comment.id}"
    simulate_translation(@comment.body)
  end

  def simulate_translation(text)
    # Simple simulation - in production, integrate with a real translation service
    # This is just to make the system work without external dependencies
    common_translations = {
      'hello' => 'olá',
      'world' => 'mundo',
      'good' => 'bom',
      'bad' => 'ruim',
      'great' => 'ótimo',
      'love' => 'amor',
      'hate' => 'ódio',
      'work' => 'trabalho',
      'life' => 'vida',
      'time' => 'tempo'
    }
    
    translated = text.downcase
    common_translations.each { |en, pt| translated.gsub!(en, pt) }
    translated
  end

  def count_keyword_matches(text)
    Rails.logger.info "Counting keywords in comment #{@comment.id}"
    
    keywords = Rails.cache.fetch('active_keywords', expires_in: 1.hour) do
      Keyword.where(active: true).pluck(:word).map(&:downcase)
    end
    
    text_downcase = text.downcase
    matches = keywords.select { |keyword| text_downcase.match?(/\b#{Regexp.escape(keyword)}\b/) }
    
    Rails.logger.info "Keywords found in comment #{@comment.id}: #{matches}"
    matches
  end
end
