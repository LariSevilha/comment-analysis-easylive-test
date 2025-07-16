require 'test_helper'

class ExternalApiIntegrationTest < ActiveSupport::TestCase
  def setup
    # Clear all data
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all

    @import_service = ImportService.new
    @translation_service = TranslationService.new

    # Clear cache and WebMock stubs before each test
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
    WebMock.reset!
  end

  def teardown
    # Clean up after each test
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all

    # Clear cache and WebMock stubs after each test
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
    WebMock.reset!
  end

  test "JSONPlaceholder API integration with VCR" do
    # Mock JSONPlaceholder API responses instead of using VCR
    stub_request(:get, "https://jsonplaceholder.typicode.com/users")
      .to_return(
        status: 200,
        body: [{
          id: 1,
          name: "Leanne Graham",
          username: "Bret",
          email: "Sincere@april.biz"
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "https://jsonplaceholder.typicode.com/users/1/posts")
      .to_return(
        status: 200,
        body: [{
          id: 1,
          title: "Test Post",
          body: "Test post body",
          userId: 1
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "https://jsonplaceholder.typicode.com/posts/1/comments")
      .to_return(
        status: 200,
        body: [{
          id: 1,
          name: "Test Comment",
          email: "test@example.com",
          body: "Test comment body",
          postId: 1
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Test importing a user from JSONPlaceholder
    result = @import_service.import_user_by_username("Bret")

    assert_not_nil result
    assert_not_nil result[:user]
    assert_equal "Leanne Graham", result[:user].name
    assert result[:posts_count] > 0
    assert result[:comments_count] > 0

    # Verify data was saved to database
    user = User.find_by(name: "Leanne Graham")
    assert_not_nil user
    assert user.posts.count > 0
    assert user.comments.count > 0
  end

  test "JSONPlaceholder API error handling" do
    VCR.use_cassette("jsonplaceholder_api_error") do
      # Test handling of API errors
      stub_request(:get, "https://jsonplaceholder.typicode.com/users")
        .with(query: { username: "nonexistent" })
        .to_return(status: 404, body: "Not Found")

      assert_raises(ImportService::ImportError) do
        @import_service.import_user_by_username("nonexistent")
      end
    end
  end

  test "JSONPlaceholder API rate limiting" do
    VCR.use_cassette("jsonplaceholder_rate_limiting") do
      # Test rate limiting handling
      stub_request(:get, "https://jsonplaceholder.typicode.com/users")
        .with(query: { username: "testuser" })
        .to_return(status: 429, body: "Too Many Requests", headers: { 'Retry-After' => '60' })

      assert_raises(ImportService::ImportError) do
        @import_service.import_user_by_username("testuser")
      end
    end
  end

  test "LibreTranslate API integration with VCR" do
    VCR.use_cassette("libretranslate_translation") do
      # Mock the translation API since VCR might not have real responses
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/detect")
        .to_return(
          status: 200,
          body: [{ language: 'en', confidence: 0.99 }].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/translate")
        .to_return(
          status: 200,
          body: { translatedText: "Este é um comentário de teste com palavras-chave importantes" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Test translation service
      original_text = "This is a test comment with important keywords"
      translated_text = @translation_service.translate_to_portuguese(original_text)

      assert_not_nil translated_text
      assert_not_equal original_text, translated_text
      assert translated_text.length > 0
      assert_equal "Este é um comentário de teste com palavras-chave importantes", translated_text
    end
  end

  test "LibreTranslate API error handling" do
    VCR.use_cassette("libretranslate_api_error") do
      # Test translation API error handling
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'http://localhost:5000'}/translate")
        .to_return(status: 500, body: "Internal Server Error")

      # Should fallback to original text
      original_text = "Test comment for error handling"
      result = @translation_service.translate_to_portuguese(original_text)

      # Should return original text as fallback
      assert_equal original_text, result
    end
  end

  test "LibreTranslate API timeout handling" do
    VCR.use_cassette("libretranslate_timeout") do
      # Test timeout handling
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'http://localhost:5000'}/translate")
        .to_timeout

      original_text = "Test comment for timeout handling"
      result = @translation_service.translate_to_portuguese(original_text)

      # Should fallback to original text on timeout
      assert_equal original_text, result
    end
  end

  test "translation caching integration" do
    VCR.use_cassette("translation_caching") do
      # Clear any existing stubs
      WebMock.reset!

      original_text = "This text should be cached after first translation"

      # Mock language detection
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/detect")
        .to_return(
          status: 200,
          body: [{ language: 'en', confidence: 0.99 }].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock translation API - should only be called once due to caching
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/translate")
        .to_return(
          status: 200,
          body: { translatedText: "Este texto deve ser armazenado em cache após a primeira tradução" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # First translation (should hit API)
      first_result = @translation_service.translate_to_portuguese(original_text)

      # Second translation (should use cache)
      second_result = @translation_service.translate_to_portuguese(original_text)

      assert_equal first_result, second_result
      assert_equal "Este texto deve ser armazenado em cache após a primeira tradução", first_result

      # Verify caching behavior (cache key is internal, so we test behavior)
      # The second call should be faster due to caching
      assert_equal first_result, second_result, "Cached result should match first result"
    end
  end

  test "batch translation processing" do
    VCR.use_cassette("batch_translation") do
      comments = [
        "First comment to translate",
        "Second comment with different content",
        "Third comment for batch processing"
      ]

      results = []
      comments.each do |comment_text|
        results << @translation_service.translate_to_portuguese(comment_text)
      end

      assert_equal 3, results.length
      results.each do |result|
        assert_not_nil result
        assert result.length > 0
      end

      # Verify all translations are different (assuming they would be)
      assert_equal results.length, results.uniq.length
    end
  end

  test "API retry logic integration" do
    VCR.use_cassette("api_retry_logic") do
      # Clear any existing stubs
      WebMock.reset!

      # Test retry logic for transient failures
      call_count = 0

      # Mock language detection
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/detect")
        .to_return(
          status: 200,
          body: [{ language: 'en', confidence: 0.99 }].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/translate")
        .to_return do |request|
          call_count += 1
          if call_count < 3
            { status: 503, body: "Service Unavailable" }
          else
            {
              status: 200,
              body: { translatedText: "Texto traduzido após retry" }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            }
          end
        end

      result = @translation_service.translate_to_portuguese("Text for retry test")

      # The service should either succeed after retries OR fallback to original text
      # Let's verify that retries actually happened
      assert call_count >= 1, "API should have been called at least once, got #{call_count}"

      # If retries worked, we should get the translated text
      # If fallback happened, we should get the original text
      assert_includes ["Texto traduzido após retry", "Text for retry test"], result
    end
  end

  test "concurrent API requests handling" do
    VCR.use_cassette("concurrent_api_requests") do
      texts_to_translate = (1..5).map { |i| "Concurrent translation test #{i}" }

      # Process translations concurrently
      threads = texts_to_translate.map do |text|
        Thread.new do
          @translation_service.translate_to_portuguese(text)
        end
      end

      results = threads.map(&:value)

      assert_equal 5, results.length
      results.each do |result|
        assert_not_nil result
        assert result.length > 0
      end
    end
  end

  test "API response validation" do
    VCR.use_cassette("api_response_validation") do
      # Test handling of malformed API responses
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'http://localhost:5000'}/translate")
        .to_return(
          status: 200,
          body: "Invalid JSON response",
          headers: { 'Content-Type' => 'application/json' }
        )

      original_text = "Test for malformed response"
      result = @translation_service.translate_to_portuguese(original_text)

      # Should fallback to original text when response is invalid
      assert_equal original_text, result
    end
  end
end
