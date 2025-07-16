require 'test_helper'

class TranslationServiceTest < ActiveSupport::TestCase
  def setup
    @service = TranslationService.new
    @sample_text = "Hello, this is a test comment."
    @translated_text = "Olá, este é um comentário de teste."
    @portuguese_text = "Este texto já está em português."

    # Enable caching for tests by using memory store
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
  end

  def teardown
    # Restore original cache store
    Rails.cache = @original_cache_store
  end

  test "should translate text to Portuguese successfully" do
    # Mock language detection
    detect_response = mock_response([{ 'language' => 'en' }])
    TranslationService.expects(:post).with('/detect', anything).returns(detect_response)

    # Mock translation
    translate_response = mock_response({ 'translatedText' => @translated_text })
    TranslationService.expects(:post).with('/translate', anything).returns(translate_response)

    result = @service.translate_to_portuguese(@sample_text)

    assert_equal @translated_text, result
  end

  test "should return cached translation when available" do
    # First, let's make sure we understand the cache key
    cache_key = @service.send(:translation_cache_key, @sample_text)

    # Manually cache a translation
    Rails.cache.write(cache_key, @translated_text)

    # Verify cache is working
    cached_result = Rails.cache.read(cache_key)
    assert_equal @translated_text, cached_result, "Cache should contain the translation"

    # Now test the service - it should return cached result without API calls
    result = @service.translate_to_portuguese(@sample_text)

    assert_equal @translated_text, result
  end

  test "should skip translation for Portuguese text" do
    # Mock language detection to return Portuguese
    detect_response = mock_response([{ 'language' => 'pt' }])
    TranslationService.expects(:post).with('/detect', anything).returns(detect_response)

    # Should not call translate endpoint
    TranslationService.expects(:post).with('/translate', anything).never

    result = @service.translate_to_portuguese(@portuguese_text)

    assert_equal @portuguese_text, result
  end

  test "should return nil for blank text" do
    assert_nil @service.translate_to_portuguese(nil)
    assert_nil @service.translate_to_portuguese("")
    assert_nil @service.translate_to_portuguese("   ")
  end

  test "should fallback to original text on API failure" do
    # Mock language detection
    detect_response = mock_response([{ 'language' => 'en' }])
    TranslationService.expects(:post).with('/detect', anything).returns(detect_response)

    # Mock translation failure
    error_response = mock('response')
    error_response.stubs(:success?).returns(false)
    error_response.stubs(:code).returns(500)
    error_response.stubs(:body).returns('Internal Server Error')

    TranslationService.expects(:post).with('/translate', anything).returns(error_response)

    result = @service.translate_to_portuguese(@sample_text)

    # Should return original text as fallback
    assert_equal @sample_text, result
  end

  test "should fallback to original text on network error" do
    # Mock language detection - may be called multiple times due to retries
    detect_response = mock_response([{ 'language' => 'en' }])
    TranslationService.expects(:post).with('/detect', anything).returns(detect_response).at_least_once

    # Mock network error - the service will retry internally
    TranslationService.expects(:post).with('/translate', anything).raises(Timeout::Error).at_least_once

    result = @service.translate_to_portuguese(@sample_text)

    # Should return original text as fallback
    assert_equal @sample_text, result
  end

  test "should handle language detection failure gracefully" do
    # Mock language detection failure
    error_response = mock('response')
    error_response.stubs(:success?).returns(false)
    error_response.stubs(:code).returns(500)

    TranslationService.expects(:post).with('/detect', anything).returns(error_response)

    # Should default to English and proceed with translation
    translate_response = mock_response({ 'translatedText' => @translated_text })
    TranslationService.expects(:post).with('/translate', anything).returns(translate_response)

    result = @service.translate_to_portuguese(@sample_text)
    assert_equal @translated_text, result
  end

  test "should translate batch of texts" do
    texts = [@sample_text, "Another text", "Third text"]
    translations = [@translated_text, "Outro texto", "Terceiro texto"]

    # Mock API calls for each text in sequence
    sequence = sequence('batch_sequence')
    texts.each_with_index do |text, index|
      detect_response = mock_response([{ 'language' => 'en' }])
      translate_response = mock_response({ 'translatedText' => translations[index] })

      TranslationService.expects(:post).with('/detect', anything).returns(detect_response).in_sequence(sequence)
      TranslationService.expects(:post).with('/translate', anything).returns(translate_response).in_sequence(sequence)
    end

    results = @service.translate_batch(texts)

    assert_equal translations, results
  end

  test "should return empty array for blank batch" do
    assert_equal [], @service.translate_batch(nil)
    assert_equal [], @service.translate_batch([])
  end

  test "should check service availability" do
    # Mock successful languages endpoint
    languages_response = mock_response([{ 'code' => 'en', 'name' => 'English' }])
    TranslationService.expects(:get).with('/languages', anything).returns(languages_response)

    assert @service.service_available?
  end

  test "should return false when service unavailable" do
    # Mock failed languages endpoint
    error_response = mock('response')
    error_response.stubs(:success?).returns(false)
    TranslationService.expects(:get).with('/languages', anything).returns(error_response)

    assert_not @service.service_available?
  end

  test "should return false when service raises exception" do
    # Mock the with_retry method to raise an exception
    @service.expects(:with_retry).raises(Timeout::Error)

    assert_not @service.service_available?
  end

  test "should generate consistent cache keys" do
    text1 = "Hello World"
    text2 = "Different text"

    key1 = @service.send(:translation_cache_key, text1)
    key2 = @service.send(:translation_cache_key, text2)
    key3 = @service.send(:translation_cache_key, text1) # Same as text1

    # Same text should generate same key
    assert_equal key1, key3
    # Different text should generate different key
    assert_not_equal key1, key2
  end

  test "should handle invalid API response format" do
    # Mock language detection
    detect_response = mock_response([{ 'language' => 'en' }])
    TranslationService.expects(:post).with('/detect', anything).returns(detect_response)

    # Mock invalid response format
    invalid_response = mock_response({ 'error' => 'Invalid request' })
    TranslationService.expects(:post).with('/translate', anything).returns(invalid_response)

    result = @service.translate_to_portuguese(@sample_text)

    # Should fallback to original text
    assert_equal @sample_text, result
  end

  test "should handle different HTTP error codes appropriately" do
    # Test a few representative error codes
    [400, 500, 503].each do |error_code|
      # Clear cache and create new service instance for each test
      Rails.cache.clear
      service = TranslationService.new

      # Mock language detection
      detect_response = mock_response([{ 'language' => 'en' }])
      TranslationService.expects(:post).with('/detect', anything).returns(detect_response)

      error_response = mock('response')
      error_response.stubs(:success?).returns(false)
      error_response.stubs(:code).returns(error_code)
      error_response.stubs(:body).returns("Error #{error_code}")

      TranslationService.expects(:post).with('/translate', anything).returns(error_response)

      result = service.translate_to_portuguese(@sample_text)

      # Should fallback to original text for all error codes
      assert_equal @sample_text, result
    end
  end

  test "should retry on rate limit errors" do
    # Mock language detection - may be called multiple times due to retries
    detect_response = mock_response([{ 'language' => 'en' }])
    TranslationService.expects(:post).with('/detect', anything).returns(detect_response).at_least_once

    # Mock rate limit response - service should retry and eventually fallback
    rate_limit_response = mock('response')
    rate_limit_response.stubs(:success?).returns(false)
    rate_limit_response.stubs(:code).returns(429)
    rate_limit_response.stubs(:body).returns('Rate limit exceeded')

    # Expect multiple rate limit responses (retries)
    TranslationService.expects(:post).with('/translate', anything).returns(rate_limit_response).at_least_once

    result = @service.translate_to_portuguese(@sample_text)

    # Should fallback to original text after retries are exhausted
    assert_equal @sample_text, result
  end

  private

  def mock_response(data)
    response = mock('response')
    response.stubs(:success?).returns(true)
    response.stubs(:parsed_response).returns(data)
    response
  end
end
