# frozen_string_literal: true

require 'test_helper'

class Api::CacheControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Use memory store for tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    # Reset cache statistics
    CacheManager.reset_stats
  end

  def teardown
    # Restore original cache store
    Rails.cache = @original_cache_store
  end

  test "should get cache health report" do
    # Perform some cache operations to generate data
    CacheManager.write('test_key', 'test_value', cache_type: :translation)
    CacheManager.read('test_key', cache_type: :translation)

    get '/api/cache/health'

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']

    data = json_response['data']
    assert_includes data.keys, 'overall_health'
    assert_includes data.keys, 'statistics'
    assert_includes data.keys, 'performance_metrics'
    assert_includes data.keys, 'recommendations'
    assert_includes data.keys, 'alerts'

    # Health should be a number
    assert data['overall_health'].is_a?(Numeric)
    assert data['overall_health'] >= 0
    assert data['overall_health'] <= 100
  end

  test "should get cache statistics" do
    # Perform some cache operations
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.read('key1', cache_type: :translation)
    CacheManager.read('missing', cache_type: :translation)

    get '/api/cache/stats'

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']

    data = json_response['data']
    assert_includes data.keys, 'statistics'
    assert_includes data.keys, 'performance'
    assert_includes data.keys, 'timestamp'

    stats = data['statistics']
    assert_equal 1, stats['hits']
    assert_equal 1, stats['misses']
    assert_equal 1, stats['writes']
    assert_equal 50.0, stats['hit_ratio']
  end

  test "should schedule cache warming" do
    post '/api/cache/warm', params: { type: 'keywords' }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_includes json_response['message'], 'Cache warming job queued'
    assert_equal 'keywords', json_response['warming_type']
    assert_equal 0, json_response['delay']
  end

  test "should schedule cache warming with delay" do
    post '/api/cache/warm', params: { type: 'full', delay: 30 }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_includes json_response['message'], 'scheduled in 30 seconds'
    assert_equal 'full', json_response['warming_type']
    assert_equal 30, json_response['delay']
  end

  test "should reject invalid warming type" do
    post '/api/cache/warm', params: { type: 'invalid_type' }

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_includes json_response['message'], 'Invalid warming type'
  end

  test "should invalidate specific cache type" do
    # Set up some cached data
    CacheManager.write('test_key', 'test_value', cache_type: :translation)

    delete '/api/cache/invalidate', params: { type: 'translation' }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_includes json_response['message'], 'Invalidated'
    assert_equal 'translation', json_response['cache_type']
  end

  test "should invalidate using trigger type" do
    # Set up some cached data
    CacheManager.write('all', 'keywords_data', cache_type: :keywords)
    CacheManager.write('1', 'user_data', cache_type: :user_metrics)

    delete '/api/cache/invalidate', params: { trigger: 'keyword_change' }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_includes json_response['message'], 'Cache invalidation triggered'
    assert_equal 'keyword_change', json_response['trigger_type']
  end

  test "should reject invalid cache type for invalidation" do
    delete '/api/cache/invalidate', params: { type: 'invalid_type' }

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_includes json_response['message'], 'Must specify either cache type or trigger type'
    assert_includes json_response.keys, 'available_cache_types'
    assert_includes json_response.keys, 'available_triggers'
  end

  test "should get cache configuration" do
    get '/api/cache/config'

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']

    data = json_response['data']
    assert_includes data.keys, 'cache_store'
    assert_includes data.keys, 'environment'
    assert_includes data.keys, 'ttl_strategies'
    assert_includes data.keys, 'size_limits'
    assert_includes data.keys, 'cache_prefixes'

    # Check specific values
    assert_equal 'test', data['environment']
    assert_includes data['cache_store'], 'Cache'

    # TTL strategies should be present
    ttl_strategies = data['ttl_strategies']
    assert_nil ttl_strategies['translation'] # Never expires
    assert_equal 3600, ttl_strategies['user_metrics'] # 1 hour in seconds

    # Size limits should be in MB
    size_limits = data['size_limits']
    assert_equal '50MB', size_limits['translation']
    assert_equal '10MB', size_limits['user_metrics']
  end

  test "should run cache benchmark" do
    post '/api/cache/benchmark', params: { iterations: 10 }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']

    data = json_response['data']
    assert_includes data.keys, 'iterations'
    assert_includes data.keys, 'write_performance'
    assert_includes data.keys, 'read_performance'
    assert_includes data.keys, 'delete_performance'
    assert_includes data.keys, 'overall_performance'

    assert_equal 10, data['iterations']

    # Each performance metric should have required stats
    ['write_performance', 'read_performance', 'delete_performance'].each do |perf_key|
      perf = data[perf_key]
      assert_includes perf.keys, 'avg'
      assert_includes perf.keys, 'min'
      assert_includes perf.keys, 'max'
      assert_includes perf.keys, 'p95'
    end

    assert_includes ['excellent', 'good', 'fair', 'poor'], data['overall_performance']
  end

  test "should reject benchmark with too many iterations" do
    post '/api/cache/benchmark', params: { iterations: 20000 }

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_includes json_response['message'], 'Maximum 10,000 iterations allowed'
  end

  test "should reset cache statistics" do
    # Perform some operations first
    CacheManager.write('key', 'value', cache_type: :translation)
    CacheManager.read('key', cache_type: :translation)

    # Verify we have stats
    assert CacheManager.stats[:total_operations] > 0

    post '/api/cache/reset_stats'

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_equal 'Cache statistics reset', json_response['message']

    # Stats should be reset
    assert_equal 0, CacheManager.stats[:total_operations]
  end

  test "should handle cache warming job scheduling errors gracefully" do
    # Mock job scheduling to fail
    CacheWarmingJob.stubs(:perform_later).raises(StandardError, "Job scheduling failed")

    post '/api/cache/warm', params: { type: 'full' }

    assert_response :internal_server_error

    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_includes json_response['message'], 'Failed to schedule cache warming job'
  end

  test "should handle cache invalidation errors gracefully" do
    # Mock invalidation to fail
    CacheManager.stubs(:delete_matched).raises(StandardError, "Invalidation failed")

    delete '/api/cache/invalidate', params: { type: 'translation' }

    assert_response :internal_server_error

    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_equal 'Cache invalidation failed', json_response['message']
  end

  test "should handle benchmark errors gracefully" do
    # Mock benchmark to fail
    CacheMonitor.stubs(:benchmark_operations).raises(StandardError, "Benchmark failed")

    post '/api/cache/benchmark', params: { iterations: 10 }

    assert_response :internal_server_error

    json_response = JSON.parse(response.body)
    assert_equal 'error', json_response['status']
    assert_equal 'Benchmark failed', json_response['message']
  end

  test "should use default values for missing parameters" do
    # Test warming without type parameter
    post '/api/cache/warm'

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'full', json_response['warming_type'] # Should default to 'full'
    assert_equal 0, json_response['delay'] # Should default to 0
  end

  test "should handle user-specific invalidation with user_id parameter" do
    delete '/api/cache/invalidate', params: { trigger: 'user_data_change', user_id: 123 }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'success', json_response['status']
    assert_equal 'user_data_change', json_response['trigger_type']
  end
end
