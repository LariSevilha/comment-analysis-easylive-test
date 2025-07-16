# frozen_string_literal: true

require 'test_helper'

class CacheManagerTest < ActiveSupport::TestCase
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

  test "should track cache statistics correctly" do
    # Test cache write
    CacheManager.write('test_key', 'test_value', cache_type: :translation)
    assert_equal 1, CacheManager.write_count

    # Test cache hit
    result = CacheManager.read('test_key', cache_type: :translation)
    assert_equal 'test_value', result
    assert_equal 1, CacheManager.hit_count

    # Test cache miss
    result = CacheManager.read('nonexistent_key', cache_type: :translation)
    assert_nil result
    assert_equal 1, CacheManager.miss_count

    # Test cache delete
    CacheManager.delete('test_key', cache_type: :translation)
    assert_equal 1, CacheManager.delete_count
  end

  test "should calculate hit ratio correctly" do
    # No operations yet
    assert_equal 0.0, CacheManager.hit_ratio

    # Add some hits and misses
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.read('key1', cache_type: :translation) # hit
    CacheManager.read('key2', cache_type: :translation) # miss
    CacheManager.read('key1', cache_type: :translation) # hit

    # Should be 2 hits out of 3 reads = 66.67%
    assert_equal 66.67, CacheManager.hit_ratio
  end

  test "should build cache keys with proper prefixes" do
    # Test different cache types
    CacheManager.write('test', 'value', cache_type: :translation)
    CacheManager.write('test', 'value', cache_type: :user_metrics)

    # Verify they're stored separately
    translation_result = CacheManager.read('test', cache_type: :translation)
    metrics_result = CacheManager.read('test', cache_type: :user_metrics)

    assert_equal 'value', translation_result
    assert_equal 'value', metrics_result

    # But they should be different cache keys internally
    assert_equal 2, CacheManager.write_count
  end

  test "should use correct TTL strategies" do
    # Translation cache should never expire (nil TTL)
    assert_nil CacheManager::TTL_STRATEGIES[:translation]

    # User metrics should expire in 1 hour
    assert_equal 1.hour, CacheManager::TTL_STRATEGIES[:user_metrics]

    # Keywords should expire in 30 minutes
    assert_equal 30.minutes, CacheManager::TTL_STRATEGIES[:keywords]
  end

  test "should fetch with block and track statistics" do
    call_count = 0

    # First call should execute block (cache miss)
    result1 = CacheManager.fetch('fetch_test', cache_type: :user_metrics) do
      call_count += 1
      'computed_value'
    end

    assert_equal 'computed_value', result1
    assert_equal 1, call_count
    assert_equal 1, CacheManager.miss_count

    # Second call should use cache (cache hit)
    result2 = CacheManager.fetch('fetch_test', cache_type: :user_metrics) do
      call_count += 1
      'should_not_be_called'
    end

    assert_equal 'computed_value', result2
    assert_equal 1, call_count # Block should not be called again
    assert_equal 1, CacheManager.hit_count
  end

  test "should invalidate related caches correctly" do
    # Set up some cached data
    CacheManager.write('user_1', 'user_data', cache_type: :user_metrics)
    CacheManager.write('all', 'group_data', cache_type: :group_metrics)
    CacheManager.write('all', 'keywords_data', cache_type: :keywords)

    # Verify data is cached
    assert_not_nil CacheManager.read('user_1', cache_type: :user_metrics)
    assert_not_nil CacheManager.read('all', cache_type: :group_metrics)
    assert_not_nil CacheManager.read('all', cache_type: :keywords)

    # Invalidate keyword-related caches
    CacheManager.invalidate_related_caches(:keyword_change)

    # Keywords, user metrics, and group metrics should be cleared
    assert_nil CacheManager.read('all', cache_type: :keywords)
    assert_nil CacheManager.read('user_1', cache_type: :user_metrics)
    assert_nil CacheManager.read('all', cache_type: :group_metrics)
  end

  test "should handle user-specific cache invalidation" do
    # Set up user-specific cached data
    CacheManager.write('1', 'user_1_data', cache_type: :user_metrics)
    CacheManager.write('2', 'user_2_data', cache_type: :user_metrics)
    CacheManager.write('all', 'group_data', cache_type: :group_metrics)

    # Invalidate specific user's cache
    CacheManager.invalidate_related_caches(:user_data_change, user_id: 1)

    # Only user 1's cache should be cleared, group metrics should also be cleared
    assert_nil CacheManager.read('1', cache_type: :user_metrics)
    assert_not_nil CacheManager.read('2', cache_type: :user_metrics)
    assert_nil CacheManager.read('all', cache_type: :group_metrics)
  end

  test "should provide comprehensive statistics" do
    # Perform various cache operations
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.write('key2', 'value2', cache_type: :user_metrics)
    CacheManager.read('key1', cache_type: :translation) # hit
    CacheManager.read('key3', cache_type: :translation) # miss
    CacheManager.delete('key1', cache_type: :translation)

    stats = CacheManager.stats

    assert_equal 2, stats[:writes]
    assert_equal 1, stats[:hits]
    assert_equal 1, stats[:misses]
    assert_equal 1, stats[:deletes]
    assert_equal 5, stats[:total_operations]
    assert_equal 50.0, stats[:hit_ratio] # 1 hit out of 2 reads
  end

  test "should handle cache size limits" do
    # This is a basic test since we can't easily test actual size limits in memory store
    large_value = 'x' * 1000

    # Should write successfully for reasonable sizes
    result = CacheManager.write('large_key', large_value, cache_type: :translation)
    assert result

    # Verify it was written
    assert_equal large_value, CacheManager.read('large_key', cache_type: :translation)
  end

  test "should clear all caches" do
    # Set up data in different cache types
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.write('key2', 'value2', cache_type: :user_metrics)
    CacheManager.write('key3', 'value3', cache_type: :keywords)

    # Verify data exists
    assert_not_nil CacheManager.read('key1', cache_type: :translation)
    assert_not_nil CacheManager.read('key2', cache_type: :user_metrics)
    assert_not_nil CacheManager.read('key3', cache_type: :keywords)

    # Clear all caches
    CacheManager.clear_all_caches

    # Stats should be reset immediately after clearing
    assert_equal 0, CacheManager.hit_count
    assert_equal 0, CacheManager.miss_count

    # All data should be gone (these reads will increment miss_count)
    assert_nil CacheManager.read('key1', cache_type: :translation)
    assert_nil CacheManager.read('key2', cache_type: :user_metrics)
    assert_nil CacheManager.read('key3', cache_type: :keywords)

    # After the reads, we should have 3 misses
    assert_equal 3, CacheManager.miss_count
  end

  test "should provide cache size information" do
    size_info = CacheManager.cache_size_info

    # Should include all cache types
    assert_includes size_info.keys, :translation
    assert_includes size_info.keys, :user_metrics
    assert_includes size_info.keys, :keywords

    # Each should have limit and TTL info
    translation_info = size_info[:translation]
    assert_equal 50.megabytes, translation_info[:limit]
    assert_nil translation_info[:ttl] # Never expires

    user_metrics_info = size_info[:user_metrics]
    assert_equal 10.megabytes, user_metrics_info[:limit]
    assert_equal 1.hour, user_metrics_info[:ttl]
  end

  test "should reset statistics correctly" do
    # Perform some operations
    CacheManager.write('key', 'value', cache_type: :translation)
    CacheManager.read('key', cache_type: :translation)
    CacheManager.read('missing', cache_type: :translation)

    # Verify stats are not zero
    assert CacheManager.hit_count > 0
    assert CacheManager.miss_count > 0
    assert CacheManager.write_count > 0

    # Reset stats
    CacheManager.reset_stats

    # All stats should be zero
    assert_equal 0, CacheManager.hit_count
    assert_equal 0, CacheManager.miss_count
    assert_equal 0, CacheManager.write_count
    assert_equal 0, CacheManager.delete_count
    assert_equal 0.0, CacheManager.hit_ratio
  end
end
