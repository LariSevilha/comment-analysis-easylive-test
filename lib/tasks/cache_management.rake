# frozen_string_literal: true

namespace :cache do
  desc "Display cache health report"
  task health: :environment do
    puts "\n=== Cache Health Report ==="
    puts "Generated at: #{Time.current}"
    puts "=" * 50

    report = CacheMonitor.health_report

    puts "\nOverall Health: #{report[:overall_health]}%"

    case report[:overall_health]
    when 90..100
      puts "Status: EXCELLENT ✅"
    when 70..89
      puts "Status: GOOD ✅"
    when 50..69
      puts "Status: FAIR ⚠️"
    else
      puts "Status: POOR ❌"
    end

    puts "\n--- Statistics ---"
    stats = report[:statistics]
    puts "Hit Ratio: #{stats[:hit_ratio]}%"
    puts "Total Operations: #{stats[:total_operations]}"
    puts "  - Hits: #{stats[:hits]}"
    puts "  - Misses: #{stats[:misses]}"
    puts "  - Writes: #{stats[:writes]}"
    puts "  - Deletes: #{stats[:deletes]}"

    puts "\n--- Performance Metrics ---"
    perf = report[:performance_metrics]
    puts "Efficiency Score: #{perf[:efficiency_score]}%"
    puts "Read Operations: #{perf[:operations_breakdown][:reads]}"
    puts "Write Operations: #{perf[:operations_breakdown][:writes]}"
    puts "Delete Operations: #{perf[:operations_breakdown][:deletes]}"

    if report[:recommendations].any?
      puts "\n--- Recommendations ---"
      report[:recommendations].each_with_index do |rec, index|
        puts "#{index + 1}. [#{rec[:severity].upcase}] #{rec[:message]}"
        puts "   Action: #{rec[:action]}"
      end
    end

    if report[:alerts].any?
      puts "\n--- Alerts ---"
      report[:alerts].each do |alert|
        puts "[#{alert[:level].upcase}] #{alert[:message]} (#{alert[:timestamp]})"
      end
    end

    puts "\n--- Cache Size Information ---"
    report[:size_information].each do |type, info|
      puts "#{type.to_s.humanize}: Limit #{info[:limit] ? "#{info[:limit] / 1.megabyte}MB" : 'None'}, TTL: #{info[:ttl] || 'Never expires'}"
    end

    puts "\n" + "=" * 50
  end

  desc "Warm cache with frequently accessed data"
  task warm: :environment do
    puts "Starting cache warming..."

    start_time = Time.current
    CacheManager.reset_stats

    CacheManager.warm_cache

    duration = Time.current - start_time
    stats = CacheManager.stats

    puts "Cache warming completed!"
    puts "Duration: #{duration.round(2)} seconds"
    puts "Operations performed: #{stats[:total_operations]}"
    puts "Cache writes: #{stats[:writes]}"
    puts "Current hit ratio: #{stats[:hit_ratio]}%"
  end

  desc "Test cache warming effectiveness"
  task test_warming: :environment do
    puts "Testing cache warming effectiveness..."

    results = CacheMonitor.test_cache_warming

    puts "\n=== Cache Warming Test Results ==="
    puts "Warming Time: #{results[:warming_time]} seconds"
    puts "Test Access Time: #{results[:test_time]} seconds"
    puts "Hit Ratio After Warming: #{results[:hit_ratio_after_warming]}%"
    puts "Total Operations: #{results[:total_operations]}"
    puts "Effectiveness Score: #{results[:effectiveness_score]}%"

    if results[:effectiveness_score] > 80
      puts "Status: EXCELLENT ✅"
    elsif results[:effectiveness_score] > 60
      puts "Status: GOOD ✅"
    elsif results[:effectiveness_score] > 40
      puts "Status: FAIR ⚠️"
    else
      puts "Status: POOR ❌"
    end
  end

  desc "Benchmark cache operations"
  task benchmark: :environment do
    iterations = ENV['ITERATIONS']&.to_i || 1000
    puts "Running cache benchmark with #{iterations} iterations..."

    results = CacheMonitor.benchmark_operations(iterations: iterations)

    puts "\n=== Cache Benchmark Results ==="
    puts "Iterations: #{results[:iterations]}"
    puts "Overall Performance: #{results[:overall_performance].upcase}"

    puts "\n--- Write Performance ---"
    write_perf = results[:write_performance]
    puts "Average: #{write_perf[:avg]}ms"
    puts "Min: #{write_perf[:min]}ms"
    puts "Max: #{write_perf[:max]}ms"
    puts "95th Percentile: #{write_perf[:p95]}ms"

    puts "\n--- Read Performance ---"
    read_perf = results[:read_performance]
    puts "Average: #{read_perf[:avg]}ms"
    puts "Min: #{read_perf[:min]}ms"
    puts "Max: #{read_perf[:max]}ms"
    puts "95th Percentile: #{read_perf[:p95]}ms"

    puts "\n--- Delete Performance ---"
    delete_perf = results[:delete_performance]
    puts "Average: #{delete_perf[:avg]}ms"
    puts "Min: #{delete_perf[:min]}ms"
    puts "Max: #{delete_perf[:max]}ms"
    puts "95th Percentile: #{delete_perf[:p95]}ms"
  end

  desc "Clear all application caches (use with caution)"
  task clear: :environment do
    print "Are you sure you want to clear ALL caches? This will impact performance. (y/N): "
    response = STDIN.gets.chomp.downcase

    if response == 'y' || response == 'yes'
      puts "Clearing all caches..."
      CacheManager.clear_all_caches
      puts "All caches cleared!"
    else
      puts "Cache clear cancelled."
    end
  end

  desc "Reset cache monitoring statistics"
  task reset_stats: :environment do
    CacheManager.reset_stats
    puts "Cache monitoring statistics reset."
  end

  desc "Show current cache statistics"
  task stats: :environment do
    stats = CacheManager.stats

    puts "\n=== Current Cache Statistics ==="
    puts "Hit Ratio: #{stats[:hit_ratio]}%"
    puts "Total Operations: #{stats[:total_operations]}"
    puts "Hits: #{stats[:hits]}"
    puts "Misses: #{stats[:misses]}"
    puts "Writes: #{stats[:writes]}"
    puts "Deletes: #{stats[:deletes]}"

    if stats[:total_operations] > 0
      puts "\nOperation Breakdown:"
      total = stats[:total_operations].to_f
      puts "  Reads: #{((stats[:hits] + stats[:misses]) / total * 100).round(1)}%"
      puts "  Writes: #{(stats[:writes] / total * 100).round(1)}%"
      puts "  Deletes: #{(stats[:deletes] / total * 100).round(1)}%"
    end
  end

  desc "Schedule cache warming job"
  task schedule_warming: :environment do
    warming_type = ENV['TYPE'] || 'full'
    delay = ENV['DELAY']&.to_i || 0

    if delay > 0
      CacheWarmingJob.set(wait: delay.seconds).perform_later(warming_type: warming_type)
      puts "Cache warming job scheduled to run in #{delay} seconds (type: #{warming_type})"
    else
      CacheWarmingJob.perform_later(warming_type: warming_type)
      puts "Cache warming job queued (type: #{warming_type})"
    end
  end

  desc "Invalidate specific cache type"
  task :invalidate, [:cache_type] => :environment do |task, args|
    cache_type = args[:cache_type]&.to_sym

    unless CacheManager::CACHE_PREFIXES.key?(cache_type)
      puts "Invalid cache type. Available types:"
      CacheManager::CACHE_PREFIXES.keys.each { |type| puts "  - #{type}" }
      exit 1
    end

    deleted_count = CacheManager.delete_matched("*", cache_type: cache_type)
    puts "Invalidated #{deleted_count} cache entries for type: #{cache_type}"
  end

  desc "Show cache configuration"
  task config: :environment do
    puts "\n=== Cache Configuration ==="
    puts "Cache Store: #{Rails.cache.class.name}"
    puts "Environment: #{Rails.env}"

    if Rails.cache.respond_to?(:options)
      puts "Options: #{Rails.cache.options}"
    end

    puts "\n--- TTL Strategies ---"
    CacheManager::TTL_STRATEGIES.each do |type, ttl|
      puts "#{type.to_s.humanize}: #{ttl || 'Never expires'}"
    end

    puts "\n--- Size Limits ---"
    CacheManager::SIZE_LIMITS.each do |type, limit|
      puts "#{type.to_s.humanize}: #{limit / 1.megabyte}MB"
    end
  end
end
