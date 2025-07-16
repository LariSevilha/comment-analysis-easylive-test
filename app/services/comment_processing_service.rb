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
      Rails.logger.error "Error processing comment #{@comment.id}: #{e.message}"
      @comment.rejeitar! if @comment.processando?
    end
  
    private
  
    def translate_comment
      Rails.logger.info "Translating comment #{@comment.id}"
      client = LibreTranslate::Client.new('http://libretranslate:5000') # Ajuste a URL
      client.translate(@comment.body, source: 'en', target: 'pt')
    rescue StandardError => e
      Rails.logger.error "Translation failed for comment #{@comment.id}: #{e.message}"
      @comment.body # Fallback
    end
  
    def count_keyword_matches(text)
      Rails.logger.info "Counting keywords in comment #{@comment.id}"
      keywords = Keyword.pluck(:word).map(&:downcase)
      text_downcase = text.downcase
      matches = keywords.select { |keyword| text_downcase.match?(/\b#{Regexp.escape(keyword)}\b/) }
      Rails.logger.info "Keywords found in comment #{@comment.id}: #{matches}"
      matches
    end
  end