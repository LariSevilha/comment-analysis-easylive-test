# frozen_string_literal: true

class CacheWarmingJob < ApplicationJob
  queue_as :default

  # Retry configuration for cache warming
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(warming_type: 'full', specific_data: nil)
    Rails.logger.info "Starting cache warming job (type: #{warming_type})"

    start_time = Time.current

    case warming_type.to_s
    when 'full'
      perform_full_cache_warming
    when 'keywords'
      warm_keywords_only
    when 'metrics'
      warm_metrics_only
    when 'user_specific'
      warm_user_specific_data(specific_data)
    when 'translations'
      warm_frequent_translations
    else
      Rails.logger.warn "Unknown cache warming type: #{warming_type}"
      return
    end

    duration = Time.current - start_time
    Rails.logger.info "Cache warming completed in #{duration.round(2)} seconds"

    # Log warming effectiveness
    log_warming_results(warming_type, duration)

  rescue => e
    Rails.logger.error "Cache warming failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  private

  def perform_full_cache_warming
    Rails.logger.info "Performing full cache warming"

    # Reset cache statistics to measure warming effectiveness
    CacheManager.reset_stats

    # Warm different types of cache data
    warm_keywords_cache
    warm_group_metrics_cache
    warm_frequent_user_metrics
    warm_frequent_translations
    warm_job_progress_cache

    Rails.logger.info "Full cache warming completed"
  end

  def warm_keywords_only
    Rails.logger.info "Warming keywords cache only"
    warm_keywords_cache
  end

  def warm_metrics_only
    Rails.logger.info "Warming metrics cache only"
    warm_group_metrics_cache
    warm_frequent_user_metrics
  end

  def warm_user_specific_data(user_data)
    return unless user_data.is_a?(Hash) && user_data['user_ids']

    user_ids = Array(user_data['user_ids'])
    Rails.logger.info "Warming cache for specific users: #{user_ids}"

    user_ids.each do |user_id|
      begin
        # Warm user metrics
        MetricsService.calculate_user_metrics(user_id)

        # Warm user's comment translations if they exist
        user = User.find(user_id)
        user.comments.limit(10).each do |comment|
          if comment.body.present?
            TranslationService.new.translate_to_portuguese(comment.body)
          end
        end

      rescue ActiveRecord::RecordNotFound
        Rails.logger.warn "User #{user_id} not found during cache warming"
      rescue => e
        Rails.logger.error "Failed to warm cache for user #{user_id}: #{e.message}"
      end
    end
  end

  def warm_frequent_translations
    Rails.logger.info "Warming frequent translations cache"

    # Get most common comment patterns for translation warming
    common_phrases = [
      "Great post!",
      "Thank you for sharing",
      "This is very helpful",
      "I agree with this",
      "Interesting perspective",
      "Well written article",
      "Thanks for the information",
      "Good point",
      "I learned something new",
      "Excellent work"
    ]

    translation_service = TranslationService.new

    common_phrases.each do |phrase|
      begin
        translation_service.translate_to_portuguese(phrase)
      rescue => e
        Rails.logger.warn "Failed to warm translation for '#{phrase}': #{e.message}"
      end
    end
  end

  def warm_keywords_cache
    Rails.logger.debug "Warming keywords cache"

    begin
      # This will cache the keywords list
      keywords = Keyword.all.order(:word).pluck(:id, :word).map { |id, word| { id: id, word: word } }
      CacheManager.write('all', keywords, cache_type: :keywords)

      # Also cache individual keyword lookups that might be frequent
      keywords.each do |keyword_data|
        CacheManager.write(
          "keyword_#{keyword_data[:id]}",
          keyword_data,
          cache_type: :keywords
        )
      end

      Rails.logger.debug "Keywords cache warmed with #{keywords.length} keywords"

    rescue => e
      Rails.logger.error "Failed to warm keywords cache: #{e.message}"
    end
  end

  def warm_group_metrics_cache
    Rails.logger.debug "Warming group metrics cache"

    begin
      # This will calculate and cache group metrics
      metrics = MetricsService.calculate_group_metrics
      Rails.logger.debug "Group metrics cache warmed"

    rescue => e
      Rails.logger.error "Failed to warm group metrics cache: #{e.message}"
    end
  end

  def warm_frequent_user_metrics
    Rails.logger.debug "Warming frequent user metrics cache"

    begin
      # Get users with most comments (top 20 for warming)
      top_users = User.joins(:comments)
                     .group('users.id')
                     .order('COUNT(comments.id) DESC')
                     .limit(20)
                     .pluck(:id)

      Rails.logger.debug "Warming metrics for #{top_users.length} top users"

      top_users.each do |user_id|
        begin
          MetricsService.calculate_user_metrics(user_id)
        rescue => e
          Rails.logger.warn "Failed to warm metrics for user #{user_id}: #{e.message}"
        end
      end

      # Also warm metrics for recently active users
      recent_users = User.joins(:comments)
                        .where(comments: { created_at: 1.week.ago.. })
                        .distinct
                        .limit(10)
                        .pluck(:id)

      recent_users.each do |user_id|
        next if top_users.include?(user_id) # Skip if already warmed

        begin
          MetricsService.calculate_user_metrics(user_id)
        rescue => e
          Rails.logger.warn "Failed to warm metrics for recent user #{user_id}: #{e.message}"
        end
      end

    rescue => e
      Rails.logger.error "Failed to warm user metrics cache: #{e.message}"
    end
  end

  def warm_job_progress_cache
    Rails.logger.debug "Warming job progress cache"

    begin
      # Warm cache for recent job trackers
      recent_jobs = JobTracker.where(created_at: 1.day.ago..)
                             .limit(50)
                             .pluck(:job_id, :status, :progress, :total)

      recent_jobs.each do |job_id, status, progress, total|
        progress_data = {
          status: status,
          progress: progress || 0,
          total: total || 100,
          percentage: total && total > 0 ? (progress.to_f / total * 100).round(1) : 0
        }

        CacheManager.write(job_id, progress_data, cache_type: :job_progress)
      end

      Rails.logger.debug "Job progress cache warmed for #{recent_jobs.length} jobs"

    rescue => e
      Rails.logger.error "Failed to warm job progress cache: #{e.message}"
    end
  end

  def log_warming_results(warming_type, duration)
    stats = CacheManager.stats

    Rails.logger.info "Cache warming results for #{warming_type}:"
    Rails.logger.info "  Duration: #{duration.round(2)} seconds"
    Rails.logger.info "  Cache operations: #{stats[:total_operations]}"
    Rails.logger.info "  Cache writes: #{stats[:writes]}"
    Rails.logger.info "  Current hit ratio: #{stats[:hit_ratio]}%"

    # Store warming metrics for monitoring
    warming_metrics = {
      type: warming_type,
      duration: duration,
      operations: stats[:total_operations],
      timestamp: Time.current
    }

    CacheManager.write(
      "warming_metrics_#{Time.current.to_i}",
      warming_metrics,
      cache_type: :api_response,
      expires_in: 1.week
    )
  end
end
