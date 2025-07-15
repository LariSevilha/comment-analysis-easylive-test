class TranslationService
    include HTTParty
    
    base_uri 'https://libretranslate.de'
    
    def self.translate_to_portuguese(text)
      return text if text.blank?
        cache_key = "translation:#{Digest::MD5.hexdigest(text)}"
      
      Rails.cache.fetch(cache_key, expires_in: 1.week) do
        response = post('/translate', {
          body: {
            q: text,
            source: 'en',
            target: 'pt',
            format: 'text'
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        })
        
        if response.success?
          response.parsed_response['translatedText']
        else 
          text
        end
      end
    rescue StandardError => e
      Rails.logger.error "Translation failed: #{e.message}"
      text 
    end
  nd