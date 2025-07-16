require 'test_helper'

class Api::KeywordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Clean up any existing test keywords
    Keyword.where(word: ['test', 'example', 'updated']).destroy_all
    Rails.cache.clear

    @keyword = Keyword.create!(word: 'test')
  end

  def teardown
    # Clean up test data
    Keyword.where(word: ['test', 'example', 'updated']).destroy_all
    Rails.cache.clear
  end

  test "should get index with cached keywords" do
    # Create additional keywords for testing
    Keyword.create!(word: 'example')

    get '/api/keywords'

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['keywords']
    assert json_response['keywords'].is_a?(Array)
    assert json_response['keywords'].length >= 2

    # Verify keywords are sorted
    words = json_response['keywords'].map { |k| k['word'] }
    assert_equal words.sort, words

    # Test cache is working - make another request
    get '/api/keywords'
    assert_response :success
  end

  test "should show specific keyword" do
    get "/api/keywords/#{@keyword.id}"

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal @keyword.id, json_response['keyword']['id']
    assert_equal @keyword.word, json_response['keyword']['word']
  end

  test "should return not found for non-existent keyword" do
    get "/api/keywords/99999"

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'NOT_FOUND', json_response['error']['code']
    assert_equal 'Keyword not found', json_response['error']['message']
  end

  test "should create keyword with valid data" do
    # Mock the MetricsRecalculationJob to avoid actual job execution
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    assert_difference('Keyword.count') do
      post '/api/keywords', params: { keyword: { word: 'example' } }
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response['keyword']['id']
    assert_equal 'example', json_response['keyword']['word']
  end

  test "should not create keyword with duplicate word (case insensitive)" do
    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    assert_no_difference('Keyword.count') do
      post '/api/keywords', params: { keyword: { word: 'TEST' } }  # Same as @keyword.word but uppercase
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal 'VALIDATION_ERROR', json_response['error']['code']
    assert_includes json_response['error']['message'], 'has already been taken'
  end

  test "should not create keyword with empty word" do
    assert_no_difference('Keyword.count') do
      post '/api/keywords', params: { keyword: { word: '' } }
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal 'VALIDATION_ERROR', json_response['error']['code']
    assert_includes json_response['error']['message'], "can't be blank"
  end

  test "should update keyword with valid data" do
    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    put "/api/keywords/#{@keyword.id}", params: { keyword: { word: 'updated' } }

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal @keyword.id, json_response['keyword']['id']
    assert_equal 'updated', json_response['keyword']['word']

    @keyword.reload
    assert_equal 'updated', @keyword.word
  end

  test "should not update keyword with duplicate word" do
    # Create another keyword
    other_keyword = Keyword.create!(word: 'other')

    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    put "/api/keywords/#{@keyword.id}", params: { keyword: { word: 'other' } }

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal 'VALIDATION_ERROR', json_response['error']['code']
    assert_includes json_response['error']['message'], 'has already been taken'

    # Clean up
    other_keyword.destroy
  end

  test "should not update non-existent keyword" do
    put "/api/keywords/99999", params: { keyword: { word: 'updated' } }

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'NOT_FOUND', json_response['error']['code']
  end

  test "should destroy keyword" do
    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    assert_difference('Keyword.count', -1) do
      delete "/api/keywords/#{@keyword.id}"
    end

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 'Keyword deleted successfully', json_response['message']
  end

  test "should not destroy non-existent keyword" do
    delete "/api/keywords/99999"

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'NOT_FOUND', json_response['error']['code']
  end

  test "should invalidate cache when keyword is created" do
    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    # First request to populate cache
    get '/api/keywords'
    assert_response :success

    # Create new keyword
    post '/api/keywords', params: { keyword: { word: 'example' } }
    assert_response :created

    # Verify cache was invalidated by checking the response includes new keyword
    get '/api/keywords'
    assert_response :success
    json_response = JSON.parse(response.body)
    words = json_response['keywords'].map { |k| k['word'] }
    assert_includes words, 'example'
  end

  test "should invalidate cache when keyword is updated" do
    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    # First request to populate cache
    get '/api/keywords'
    assert_response :success

    # Update keyword
    put "/api/keywords/#{@keyword.id}", params: { keyword: { word: 'updated' } }
    assert_response :success

    # Verify cache was invalidated
    get '/api/keywords'
    assert_response :success
    json_response = JSON.parse(response.body)
    words = json_response['keywords'].map { |k| k['word'] }
    assert_includes words, 'updated'
    assert_not_includes words, 'test'
  end

  test "should invalidate cache when keyword is destroyed" do
    # Mock the MetricsRecalculationJob
    MetricsRecalculationJob.stubs(:trigger_keyword_change_recalculation)

    # Create additional keyword for testing
    extra_keyword = Keyword.create!(word: 'extra')

    # First request to populate cache
    get '/api/keywords'
    assert_response :success
    original_response = JSON.parse(response.body)
    original_count = original_response['keywords'].length

    # Delete keyword
    delete "/api/keywords/#{extra_keyword.id}"
    assert_response :success

    # Verify cache was invalidated
    get '/api/keywords'
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal original_count - 1, json_response['keywords'].length
    words = json_response['keywords'].map { |k| k['word'] }
    assert_not_includes words, 'extra'
  end
end
