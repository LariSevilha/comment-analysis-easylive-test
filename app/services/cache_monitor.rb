# frozen_string_literal: true

class CacheMonitor
  # Monitoring intervals
  MONITORING_INTERVALS = {
    short: 5.minutes,
    medium: 30.minutes,
    long: 2.hours
  }.freeze

  # Performance thresholds
  PERFORMANCE_THRESHOLDS = {
    hit_ratio_warning: 70.0,    # Warn if hit ratio below 70%
    hit_ratio_critical: 50.0,   # Critical if hit ratio below 50%
    response_time_warning: 100, # Warn if cache operations > 100ms
    response_time_critical: 500 # Critical if cache operations > 500ms
  }.freeze

  class << self
    # Get comprehensive cache health report
    def health_report
      {
        timestamp: Time.current,
        overall_health: calculate_overall_health,
        statistics: CacheManager.stats,
        performance_metrics: performance_metrics,
        size_information: CacheManager.cache_size_info,
        recommendations: generate_recommendations,
        alerts: generate_alerts
      }
    end

    # Monitor cache performance over time
    def performance_metrics
      {
        hit_ratio: CacheManager.hit_ratio,
        total_operations: CacheManager.hit_count + CacheManager.miss_count + CacheManager.write_count + CacheManager.delete_count,
        operations_breakdown: {
          reads: CacheManager.hit_count + CacheManager.miss_count,
          writes: CacheManager.write_count,
          deletes: CacheManager.delete_count
        },
        efficiency_score: calculate_efficiency_score
      }
    end

    # Generate performance recommendations
    def generate_recommendations
      recommendations = []
      hit_ratio = CacheManager.hit_ratio

      if hit_ratio < PERFORMANCE_THRESHOLDS[:hit_ratio_warning]
        recommendations << {
          type: :performance,
          severity: hit_ratio < PERFORMANCE_THRESHOLDS[:hit_ratio_critical] ? :critical : :warning,
          message: "Cache hit ratio is #{hit_ratio}%. Consider increasing TTL for frequently accessed data.",
          action: "Review cache TTL strategies and warm frequently accessed caches"
        }
      end

      if CacheManager.miss_count > CacheManager.hit_count * 2
        recommendations << {
          type: :efficiency,
          severity: :warning,
          message: "High cache miss ratio detected. Cache warming might be beneficial.",
          action: "Implement cache warming for frequently accessed data"
        }
      end

      if CacheManager.write_count > CacheManager.hit_count
        recommendations << {
          type: :usage,
          severity: :info,
          message: "More cache writes than hits. Consider if all cached data is being used.",
          action: "Review cache usage patterns and optimize cache keys"
        }
      end

      recommendations
    end

    # Generate alerts for critical issues
    def generate_alerts
      alerts = []
      hit_ratio = CacheManager.hit_ratio

      if hit_ratio < PERFORMANCE_THRESHOLDS[:hit_ratio_critical]
        alerts << {
          level: :critical,
          type: :performance,
          message: "Critical: Cache hit ratio is #{hit_ratio}%",
          timestamp: Time.current,
          action_required: true
        }
      end

      # Check for potential memory issues
      total_operations = CacheManager.hit_count + CacheManager.miss_count + CacheManager.write_count + CacheManager.delete_count
      if total_operations > 10000 && CacheManager.hit_ratio < 30
        alerts << {
          level: :warning,
          type: :memory,
          message: "High cache churn detected with low hit ratio",
          timestamp: Time.current,
          action_required: false
        }
      end

      alerts
    end

    # Calculate overall cache health score (0-100)
    def calculate_overall_health
      hit_ratio = CacheManager.hit_ratio
      efficiency = calculate_efficiency_score

      # Weighted score: 70% hit ratio, 30% efficiency
      overall_score = (hit_ratio * 0.7) + (efficiency * 0.3)

      [overall_score, 100.0].min.round(1)
    end

    # Calculate cache efficiency score
    def calculate_efficiency_score
      total_reads = CacheManager.hit_count + CacheManager.miss_count
      return 100.0 if total_reads.zero?

      # Efficiency based on read/write ratio and hit ratio
      read_write_ratio = total_reads.to_f / [CacheManager.write_count, 1].max
      hit_ratio = CacheManager.hit_ratio

      # Ideal read/write ratio is around 3:1 or higher
      ratio_score = [read_write_ratio / 3.0 * 50, 50.0].min
      hit_score = hit_ratio * 0.5

      (ratio_score + hit_score).round(1)
    end

    # Benchmark cache operations
    def benchmark_operations(iterations: 1000)
      Rails.logger.info "Starting cache benchmark with #{iterations} iterations"

      results = {
        write_times: [],
        read_times: [],
        delete_times: []
      }

      # Benchmark writes
      iterations.times do |i|
        start_time = Time.current
        CacheManager.write("benchmark_#{i}", "test_value_#{i}", cache_type: :api_response)
        results[:write_times] << (Time.current - start_time) * 1000 # Convert to milliseconds
      end

      # Benchmark reads
      iterations.times do |i|
        start_time = Time.current
        CacheManager.read("benchmark_#{i}", cache_type: :api_response)
        results[:read_times] << (Time.current - start_time) * 1000
      end

      # Benchmark deletes
      iterations.times do |i|
        start_time = Time.current
        CacheManager.delete("benchmark_#{i}", cache_type: :api_response)
        results[:delete_times] << (Time.current - start_time) * 1000
      end

      # Calculate statistics
      {
        iterations: iterations,
        write_performance: calculate_performance_stats(results[:write_times]),
        read_performance: calculate_performance_stats(results[:read_times]),
        delete_performance: calculate_performance_stats(results[:delete_times]),
        overall_performance: calculate_overall_performance(results)
      }
    end

    # Test cache warming effectiveness
    def test_cache_warming
      Rails.logger.info "Testing cache warming effectiveness"

      # Clear stats and warm cache
      CacheManager.reset_stats
      start_time = Time.current

      CacheManager.warm_cache

      warming_time = Time.current - start_time

      # Test access to warmed data
      test_start = Time.current

      # Test keywords access
      CacheManager.read('all', cache_type: :keywords)

      # Test group metrics access
      MetricsService.calculate_group_metrics

      # Test user metrics for a few users
      User.limit(5).each do |user|
        MetricsService.calculate_user_metrics(user.id)
      end

      test_time = Time.current - test_start

      {
        warming_time: warming_time.round(3),
        test_time: test_time.round(3),
        hit_ratio_after_warming: CacheManager.hit_ratio,
        total_operations: CacheManager.hit_count + CacheManager.miss_count,
        effectiveness_score: calculate_warming_effectiveness
      }
    end

    # Log cache statistics periodically
    def log_periodic_stats(interval = :medium)
      # Handle both positional and keyword arguments
      interval = interval.is_a?(Hash) ? interval[:interval] || :medium : interval

      stats = CacheManager.stats
      health = calculate_overall_health

      Rails.logger.info "Cache Statistics (#{interval} interval):"
      Rails.logger.info "  Health Score: #{health}%"
      Rails.logger.info "  Hit Ratio: #{stats[:hit_ratio]}%"
      Rails.logger.info "  Operations: #{stats[:total_operations]} (H:#{stats[:hits]}, M:#{stats[:misses]}, W:#{stats[:writes]}, D:#{stats[:deletes]})"

      # Log warnings if performance is poor
      if health < 70
        Rails.logger.warn "Cache performance is below optimal (#{health}%)"
      end

      if stats[:hit_ratio] < PERFORMANCE_THRESHOLDS[:hit_ratio_warning]
        Rails.logger.warn "Cache hit ratio is low (#{stats[:hit_ratio]}%)"
      end
    end

    # Reset monitoring data
    def reset_monitoring
      CacheManager.reset_stats
      Rails.logger.info "Cache monitoring data reset"
    end

    private

    # Calculate performance statistics for an array of times
    def calculate_performance_stats(times)
      return { avg: 0, min: 0, max: 0, p95: 0 } if times.empty?

      sorted_times = times.sort
      {
        avg: (times.sum / times.length).round(2),
        min: sorted_times.first.round(2),
        max: sorted_times.last.round(2),
        p95: sorted_times[(times.length * 0.95).to_i].round(2)
      }
    end

    # Calculate overall performance score
    def calculate_overall_performance(results)
      avg_write = results[:write_times].sum / results[:write_times].length
      avg_read = results[:read_times].sum / results[:read_times].length
      avg_delete = results[:delete_times].sum / results[:delete_times].length

      overall_avg = (avg_write + avg_read + avg_delete) / 3

      # Score based on average response time (lower is better)
      if overall_avg < 1.0
        'excellent'
      elsif overall_avg < 5.0
        'good'
      elsif overall_avg < 10.0
        'fair'
      else
        'poor'
      end
    end

    # Calculate cache warming effectiveness
    def calculate_warming_effectiveness
      hit_ratio = CacheManager.hit_ratio
      total_ops = CacheManager.hit_count + CacheManager.miss_count

      return 0 if total_ops.zero?

      # Effectiveness based on hit ratio and number of operations
      base_score = hit_ratio

      # Bonus for having actual cache operations
      operation_bonus = [total_ops / 10.0, 20.0].min

      [base_score + operation_bonus, 100.0].min.round(1)
    end
  end
end
