class TranslationService
    LIBRETRANSLATE_URL = ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.com/translate'
    
    def self.translate_to_portuguese(text)
      return text if text.blank?
        response = simulate_translation(text)
      response['translatedText'] || text
    rescue => e
      Rails.logger.error "Translation failed: #{e.message}"
      text  
    end
    
    private
    
    def self.simulate_translation(text)
      {
        'translatedText' => "#{text} (traduzido)"
      }
    end
    
    def self.call_libretranslate(text)
      response = Faraday.post(LIBRETRANSLATE_URL) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.body = {
          q: text,
          source: 'en',
          target: 'pt',
          format: 'text'
        }.to_json
      end
      
      JSON.parse(response.body)
    end
  end
  