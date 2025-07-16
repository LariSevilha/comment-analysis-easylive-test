# frozen_string_literal: true

require 'test_helper'

class CacheMonitorTest < ActiveSupport::TestCase
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

  test "should generate comprehensive health report" do
    # Perform some cache operations to generate data
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.read('key1', cache_type: :translation) # hit
    CacheManager.read('key2', cache_type: :translation) # miss

    report = CacheMonitor.health_report

    # Should include all required sections
    assert_includes report.keys, :timestamp
    assert_includes report.keys, :overall_health
    assert_includes report.keys, :statistics
    assert_includes report.keys, :performance_metrics
    assert_includes report.keys, :size_information
    assert_includes report.keys, :recommendations
    assert_includes report.keys, :alerts

    # Timestamp should be recent
    assert_in_delta Time.current.to_f, report[:timestamp].to_f, 5.0

    # Overall health should be a number between 0 and 100
    assert report[:overall_health].is_a?(Numeric)
    assert report[:overall_health] >= 0
    assert report[:overall_health] <= 100

    # Statistics should match CacheManager stats
    assert_equal CacheManager.stats, report[:statistics]
  end

  test "should calculate overall health score correctly" do
    # Test with good performance
    CacheManager.write('key1', 'value1', cache_type: :translation)
    10.times { CacheManager.read('key1', cache_type: :translation) } # 10 hits
    CacheManager.read('missing', cache_type: :translation) # 1 miss

    health = CacheMonitor.calculate_overall_health

    # Should be high with good hit ratio
    assert health > 80, "Health score should be high with good hit ratio, got #{health}"
  end

  test "should calculate efficiency score" do
    # Test with balanced read/write ratio
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.write('key2', 'value2', cache_type: :translation)
    CacheManager.write('key3', 'value3', cache_type: :translation)

    # More reads than writes (good efficiency)
    6.times { CacheManager.read('key1', cache_type: :translation) }
    3.times { CacheManager.read('key2', cache_type: :translation) }

    efficiency = CacheMonitor.calculate_efficiency_score

    assert efficiency.is_a?(Numeric)
    assert efficiency >= 0
    assert efficiency <= 100
  end

  test "should generate performance recommendations" do
    # Create scenario with low hit ratio
    CacheManager.write('key1', 'value1', cache_type: :translation)
    10.times { CacheManager.read('missing_key', cache_type: :translation) } # 10 misses
    CacheManager.read('key1', cache_type: :translation) # 1 hit

    recommendations = CacheMonitor.generate_recommendations

    assert recommendations.is_a?(Array)

    # Should have recommendation about low hit ratio
    low_hit_ratio_rec = recommendations.find { |r| r[:message].include?('hit ratio') }
    assert_not_nil low_hit_ratio_rec, "Should recommend improving hit ratio"
    assert_includes [:warning, :critical], low_hit_ratio_rec[:severity]
  end

  test "should generate alerts for critical issues" do
    # Create scenario with very low hit ratio
    20.times { CacheManager.read('missing_key', cache_type: :translation) } # 20 misses
    CacheManager.read('key1', cache_type: :translation) # 1 miss (key doesn't exist)

    alerts = CacheMonitor.generate_alerts

    assert alerts.is_a?(Array)

    # Should have critical alert for very low hit ratio
    if CacheManager.hit_ratio < CacheMonitor::PERFORMANCE_THRESHOLDS[:hit_ratio_critical]
      critical_alert = alerts.find { |a| a[:level] == :critical }
      assert_not_nil critical_alert, "Should have critical alert for very low hit ratio"
    end
  end

  test "should provide performance metrics" do
    # Perform various operations
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.write('key2', 'value2', cache_type: :user_metrics)
    CacheManager.read('key1', cache_type: :translation)
    CacheManager.read('missing', cache_type: :translation)
    CacheManager.delete('key1', cache_type: :translation)

    metrics = CacheMonitor.performance_metrics

    assert_includes metrics.keys, :hit_ratio
    assert_includes metrics.keys, :total_operations
    assert_includes metrics.keys, :operations_breakdown
    assert_includes metrics.keys, :efficiency_score

    # Operations breakdown should have correct counts
    breakdown = metrics[:operations_breakdown]
    assert_equal 2, breakdown[:reads] # 1 hit + 1 miss
    assert_equal 2, breakdown[:writes]
    assert_equal 1, breakdown[:deletes]
  end

  test "should benchmark cache operations" do
    # Run a small benchmark
    results = CacheMonitor.benchmark_operations(iterations: 10)

    assert_includes results.keys, :iterations
    assert_includes results.keys, :write_performance
    assert_includes results.keys, :read_performance
    assert_includes results.keys, :delete_performance
    assert_includes results.keys, :overall_performance

    assert_equal 10, results[:iterations]

    # Each performance section should have stats
    [:write_performance, :read_performance, :delete_performance].each do |perf_key|
      perf = results[perf_key]
      assert_includes perf.keys, :avg
      assert_includes perf.keys, :min
      assert_includes perf.keys, :max
      assert_includes perf.keys, :p95

      # All values should be non-negative
      assert perf[:avg] >= 0
      assert perf[:min] >= 0
      assert perf[:max] >= 0
      assert perf[:p95] >= 0
    end

    # Overall performance should be a string rating
    assert_includes ['excellent', 'good', 'fair', 'poor'], results[:overall_performance]
  end

  test "should test cache warming effectiveness" do
    # Create some test data first
    user = users(:one)

    # Test cache warming
    results = CacheMonitor.test_cache_warming

    assert_includes results.keys, :warming_time
    assert_includes results.keys, :test_time
    assert_includes results.keys, :hit_ratio_after_warming
    assert_includes results.keys, :total_operations
    assert_includes results.keys, :effectiveness_score

    # Times should be positive
    assert results[:warming_time] >= 0
    assert results[:test_time] >= 0

    # Effectiveness score should be between 0 and 100
    assert results[:effectiveness_score] >= 0
    assert results[:effectiveness_score] <= 100
  end

  test "should log periodic stats without errors" do
    # Perform some operations to have stats to log
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.read('key1', cache_type: :translation)

    # This should not raise any errors
    assert_nothing_raised do
      CacheMonitor.log_periodic_stats(:short)
    end
  end

  test "should reset monitoring data" do
    # Perform some operations
    CacheManager.write('key1', 'value1', cache_type: :translation)
    CacheManager.read('key1', cache_type: :translation)

    # Verify we have stats
    assert CacheManager.stats[:total_operations] > 0

    # Reset monitoring
    CacheMonitor.reset_monitoring

    # Stats should be reset
    assert_equal 0, CacheManager.stats[:total_operations]
  end

  test "should handle empty cache gracefully" do
    # Test with no cache operations
    report = CacheMonitor.health_report

    # Should not raise errors
    assert_not_nil report
    assert_equal 0.0, report[:statistics][:hit_ratio]
    assert_equal 0, report[:statistics][:total_operations]
  end

  test "should provide meaningful recommendations for different scenarios" do
    # Test high miss ratio scenario
    CacheManager.write('key1', 'value1', cache_type: :translation)
    5.times { CacheManager.read('missing', cache_type: :translation) } # 5 misses
    CacheManager.read('key1', cache_type: :translation) # 1 hit

    recommendations = CacheMonitor.generate_recommendations

    # Should recommend cache warming or TTL adjustment
    assert recommendations.any? { |r| r[:message].downcase.include?('hit ratio') || r[:message].downcase.include?('miss') }

    # Reset and test high write ratio scenario
    CacheManager.reset_stats
    10.times { |i| CacheManager.write("key#{i}", "value#{i}", cache_type: :translation) }
    2.times { CacheManager.read('key1', cache_type: :translation) }

    recommendations = CacheMonitor.generate_recommendations

    # Should recommend reviewing cache usage
    write_heavy_rec = recommendations.find { |r| r[:message].downcase.include?('write') }
    assert_not_nil write_heavy_rec if CacheManager.write_count > CacheManager.hit_count
  end
end
