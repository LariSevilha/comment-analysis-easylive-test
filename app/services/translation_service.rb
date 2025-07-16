require 'net/http'
require 'json'

class TranslationService
  LIBRETRANSLATE_URL = 'https://libretranslate.de/translate'.freeze

  def self.translate(text, target_lang = 'pt')
    return text if text.blank?
    
    # Cache para evitar traduzir o mesmo texto múltiplas vezes
    cache_key = "translation:#{Digest::MD5.hexdigest(text)}"
    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      perform_translation(text, target_lang)
    end
  rescue StandardError => e
    Rails.logger.error "Translation failed: #{e.message}"
    # Retorna o texto original se a tradução falhar
    text
  end

  private

  def self.perform_translation(text, target_lang)
    uri = URI(LIBRETRANSLATE_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      q: text,
      source: 'auto',
      target: target_lang
    }.to_json

    response = http.request(request)
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result['translatedText'] || text
    else
      Rails.logger.error "Translation API error: #{response.code} #{response.message}"
      text
    end
  end
end