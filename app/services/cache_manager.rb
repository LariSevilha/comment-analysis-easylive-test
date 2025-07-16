# frozen_string_literal: true

class CacheManager
  # Cache key prefixes for different data types
  CACHE_PREFIXES = {
    translation: 'translation',
    user_metrics: 'user_metrics',
    group_metrics: 'group_metrics',
    keywords: 'keywords',
    job_progress: 'job_progress',
    api_response: 'api_response',
    user_data: 'user_data',
    comment_analysis: 'comment_analysis',
    circuit_breaker: 'circuit_breaker',
    job_metrics: 'job_metrics',
    alerts: 'alerts'
  }.freeze

  # TTL strategies for different cache types
  TTL_STRATEGIES = {
    translation: nil,           # Never expire - translations don't change
    user_metrics: 1.hour,       # Moderate TTL - recalculated periodically
    group_metrics: 1.hour,      # Moderate TTL - recalculated periodically
    keywords: 30.minutes,       # Short TTL - may change frequently
    job_progress: 24.hours,     # Long TTL - jobs are temporary
    api_response: 5.minutes,    # Very short TTL - external data
    user_data: 2.hours,         # Medium TTL - user data changes occasionally
    comment_analysis: 4.hours,  # Medium-long TTL - analysis results are stable
    circuit_breaker: 1.hour,    # Circuit breaker state cache
    job_metrics: 24.hours,      # Job performance metrics
    alerts: 2.hours             # Alert rate limiting cache
  }.freeze

  # Cache size limits for different types (in bytes)
  SIZE_LIMITS = {
    translation: 50.megabytes,
    user_metrics: 10.megabytes,
    group_metrics: 1.megabyte,
    keywords: 1.megabyte,
    job_progress: 5.megabytes,
    api_response: 20.megabytes,
    user_data: 15.megabytes,
    comment_analysis: 25.megabytes,
    circuit_breaker: 1.megabyte,
    job_metrics: 10.megabytes,
    alerts: 5.megabytes
  }.freeze

  # Cache statistics tracking
  class << self
    attr_accessor :hit_count, :miss_count, :write_count, :delete_count

    def reset_stats
      @hit_count = 0
      @miss_count = 0
      @write_count = 0
      @delete_count = 0
    end

    # Get cache hit ratio
    def hit_ratio
      total_reads = hit_count + miss_count
      return 0.0 if total_reads.zero?

      (hit_count.to_f / total_reads * 100).round(2)
    end

    # Get cache statistics
    def stats
      {
        hits: hit_count,
        misses: miss_count,
        writes: write_count,
        deletes: delete_count,
        hit_ratio: hit_ratio,
        total_operations: hit_count + miss_count + write_count + delete_count
      }
    end
  end

  # Initialize stats
  reset_stats

  # Enhanced cache read with statistics tracking
  def self.read(key, cache_type: :default)
    full_key = build_cache_key(key, cache_type)

    result = Rails.cache.read(full_key)

    if result.nil?
      @miss_count += 1
      Rails.logger.debug "Cache MISS for key: #{full_key}"
    else
      @hit_count += 1
      Rails.logger.debug "Cache HIT for key: #{full_key}"
    end

    result
  end

  # Enhanced cache write with TTL and size management
  def self.write(key, value, cache_type: :default, expires_in: nil)
    full_key = build_cache_key(key, cache_type)
    ttl = expires_in || TTL_STRATEGIES[cache_type]

    # Check size limits
    if should_enforce_size_limit?(cache_type, value)
      Rails.logger.warn "Cache value too large for type #{cache_type}, skipping cache"
      return false
    end

    success = Rails.cache.write(full_key, value, expires_in: ttl)

    if success
      @write_count += 1
      Rails.logger.debug "Cache WRITE for key: #{full_key} (TTL: #{ttl})"
    else
      Rails.logger.error "Cache WRITE FAILED for key: #{full_key}"
    end

    success
  end

  # Enhanced cache fetch with statistics and TTL
  def self.fetch(key, cache_type: :default, expires_in: nil, &block)
    full_key = build_cache_key(key, cache_type)
    ttl = expires_in || TTL_STRATEGIES[cache_type]

    # Check if key exists first to track hits/misses properly
    existing_value = Rails.cache.read(full_key)

    if existing_value.nil?
      @miss_count += 1
      Rails.logger.debug "Cache MISS (fetch) for key: #{full_key}"

      # Compute and cache the value
      result = block.call
      Rails.cache.write(full_key, result, expires_in: ttl)
      @write_count += 1
      result
    else
      @hit_count += 1
      Rails.logger.debug "Cache HIT (fetch) for key: #{full_key}"
      existing_value
    end
  end

  # Enhanced cache delete with statistics
  def self.delete(key, cache_type: :default)
    full_key = build_cache_key(key, cache_type)

    success = Rails.cache.delete(full_key)

    if success
      @delete_count += 1
      Rails.logger.debug "Cache DELETE for key: #{full_key}"
    end

    success
  end

  # Delete multiple keys by pattern
  def self.delete_matched(pattern, cache_type: :default)
    full_pattern = build_cache_key(pattern, cache_type)

    # SolidCache doesn't support delete_matched, so we need to handle it specially
    begin
      if Rails.cache.respond_to?(:delete_matched) && !Rails.cache.is_a?(SolidCache::Store)
        deleted_count = Rails.cache.delete_matched(full_pattern)
        @delete_count += deleted_count if deleted_count.is_a?(Integer)
        Rails.logger.info "Cache DELETE_MATCHED for pattern: #{full_pattern} (#{deleted_count} keys)"
        deleted_count
      else
        # For SolidCache, we'll clear specific known keys instead of pattern matching
        Rails.logger.info "Cache store doesn't support delete_matched, clearing specific cache type: #{cache_type}"
        clear_cache_type(cache_type)
      end
    rescue NotImplementedError => e
      # Fallback for cache stores that claim to support delete_matched but don't
      Rails.logger.warn "Cache delete_matched failed: #{e.message}, falling back to cache type clearing"
      clear_cache_type(cache_type)
    end
  end

  # Intelligent cache invalidation based on data relationships
  def self.invalidate_related_caches(trigger_type, **options)
    case trigger_type
    when :keyword_change
      invalidate_keyword_related_caches
    when :user_data_change
      invalidate_user_related_caches(options[:user_id])
    when :comment_change
      invalidate_comment_related_caches(options[:user_id])
    when :metrics_recalculation
      invalidate_metrics_caches
    when :translation_update
      # Translations never expire, but we might want to clear specific ones
      delete(options[:text_hash], cache_type: :translation) if options[:text_hash]
    else
      Rails.logger.warn "Unknown cache invalidation trigger: #{trigger_type}"
    end
  end

  # Cache warming for frequently accessed data
  def self.warm_cache
    Rails.logger.info "Starting cache warming process"

    warm_keywords_cache
    warm_group_metrics_cache
    warm_frequent_user_metrics

    Rails.logger.info "Cache warming completed"
  end

  # Get cache size information
  def self.cache_size_info
    info = {}

    CACHE_PREFIXES.each do |type, prefix|
      # This is an approximation since Solid Cache doesn't provide exact size per prefix
      info[type] = {
        limit: SIZE_LIMITS[type],
        ttl: TTL_STRATEGIES[type]
      }
    end

    info
  end

  # Clear all application caches (use with caution)
  def self.clear_all_caches
    Rails.logger.warn "Clearing ALL application caches"

    # Clear the underlying cache store completely
    Rails.cache.clear

    reset_stats
  end

  # Clear all keys for a specific cache type (SolidCache workaround)
  def self.clear_cache_type(cache_type)
    Rails.logger.info "Clearing cache type: #{cache_type}"

    # For SolidCache, we can't pattern match, so we'll clear the entire cache
    # This is less efficient but ensures consistency
    case cache_type
    when :keywords, :user_metrics, :group_metrics, :comment_analysis
      # For critical cache types that affect the whole system, clear everything
      Rails.cache.clear
      Rails.logger.warn "Cleared entire cache due to #{cache_type} invalidation (SolidCache limitation)"
    else
      # For other cache types, we'll just log and continue
      Rails.logger.info "Cache type #{cache_type} cleared (no-op for SolidCache)"
    end

    @delete_count += 1
  end

  private

  # Build full cache key with prefix and namespace
  def self.build_cache_key(key, cache_type)
    prefix = CACHE_PREFIXES[cache_type] || 'default'
    namespace = Rails.env

    "#{namespace}:#{prefix}:#{key}"
  end

  # Check if value size exceeds limits
  def self.should_enforce_size_limit?(cache_type, value)
    return false unless SIZE_LIMITS[cache_type]

    # Rough size estimation
    estimated_size = value.to_s.bytesize
    estimated_size > SIZE_LIMITS[cache_type]
  end

  # Invalidate caches related to keyword changes
  def self.invalidate_keyword_related_caches
    Rails.logger.info "Invalidating keyword-related caches"

    # Clear keywords cache
    delete_matched("*", cache_type: :keywords)

    # Clear all metrics caches since keyword changes affect classification
    delete_matched("*", cache_type: :user_metrics)
    delete_matched("*", cache_type: :group_metrics)
    delete_matched("*", cache_type: :comment_analysis)
  end

  # Invalidate caches related to specific user
  def self.invalidate_user_related_caches(user_id = nil)
    if user_id
      Rails.logger.info "Invalidating caches for user #{user_id}"
      delete("#{user_id}", cache_type: :user_metrics)
      delete("#{user_id}", cache_type: :user_data)
    else
      Rails.logger.info "Invalidating all user-related caches"
      delete_matched("*", cache_type: :user_metrics)
      delete_matched("*", cache_type: :user_data)
    end

    # Always invalidate group metrics when user data changes
    delete_matched("*", cache_type: :group_metrics)
  end

  # Invalidate caches related to comment changes
  def self.invalidate_comment_related_caches(user_id = nil)
    Rails.logger.info "Invalidating comment-related caches"

    if user_id
      delete("#{user_id}", cache_type: :user_metrics)
    else
      delete_matched("*", cache_type: :user_metrics)
    end

    delete_matched("*", cache_type: :group_metrics)
    delete_matched("*", cache_type: :comment_analysis)
  end

  # Invalidate all metrics caches
  def self.invalidate_metrics_caches
    Rails.logger.info "Invalidating all metrics caches"

    delete_matched("*", cache_type: :user_metrics)
    delete_matched("*", cache_type: :group_metrics)
  end

  # Warm keywords cache
  def self.warm_keywords_cache
    Rails.logger.debug "Warming keywords cache"

    keywords = Keyword.all.order(:word).pluck(:id, :word).map { |id, word| { id: id, word: word } }
    write('all', keywords, cache_type: :keywords)
  end

  # Warm group metrics cache
  def self.warm_group_metrics_cache
    Rails.logger.debug "Warming group metrics cache"

    # This will calculate and cache group metrics
    MetricsService.calculate_group_metrics
  end

  # Warm metrics for users with most comments (top 10)
  def self.warm_frequent_user_metrics
    Rails.logger.debug "Warming frequent user metrics cache"

    # Get top 10 users by comment count
    top_users = User.joins(:comments)
                   .group('users.id')
                   .order('COUNT(comments.id) DESC')
                   .limit(10)
                   .pluck(:id)

    top_users.each do |user_id|
      MetricsService.calculate_user_metrics(user_id)
    end
  end
end
