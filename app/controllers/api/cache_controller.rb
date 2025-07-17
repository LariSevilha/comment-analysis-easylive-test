# frozen_string_literal: true

class Api::CacheController < ApplicationController
  # GET /api/cache/health
  def health
    report = CacheMonitor.health_report

    render json: {
      status: 'success',
      data: report
    }
  end

  # GET /api/cache/stats
  def stats
    stats = CacheManager.stats
    performance = CacheMonitor.performance_metrics

    render json: {
      status: 'success',
      data: {
        statistics: stats,
        performance: performance,
        timestamp: Time.current
      }
    }
  end

  # POST /api/cache/warm
  def warm
    warming_type = params[:type] || 'full'
    delay = params[:delay]&.to_i || 0

    unless %w[full keywords metrics user_specific translations].include?(warming_type)
      return render json: {
        status: 'error',
        message: 'Invalid warming type. Valid types: full, keywords, metrics, user_specific, translations'
      }, status: :bad_request
    end

    begin
      if delay > 0
        CacheWarmingJob.set(wait: delay.seconds).perform_later(warming_type: warming_type)
        message = "Cache warming scheduled in #{delay} seconds"
      else
        CacheWarmingJob.perform_later(warming_type: warming_type)
        message = "Cache warming job queued"
      end

      render json: {
        status: 'success',
        message: message,
        warming_type: warming_type,
        delay: delay
      }
    rescue => e
      Rails.logger.error "Failed to schedule cache warming: #{e.message}"
      render json: {
        status: 'error',
        message: 'Failed to schedule cache warming job'
      }, status: :internal_server_error
    end
  end

  # DELETE /api/cache/invalidate
  def invalidate
    cache_type = params[:type]&.to_sym
    trigger_type = params[:trigger]&.to_sym

    begin
      if cache_type && CacheManager::CACHE_PREFIXES.key?(cache_type)
        # Invalidate specific cache type
        deleted_count = CacheManager.delete_matched("*", cache_type: cache_type)

        render json: {
          status: 'success',
          message: "Invalidated #{deleted_count} cache entries",
          cache_type: cache_type,
          deleted_count: deleted_count
        }
      elsif trigger_type
        # Use intelligent invalidation
        CacheManager.invalidate_related_caches(trigger_type, **invalidation_options)

        render json: {
          status: 'success',
          message: "Cache invalidation triggered",
          trigger_type: trigger_type
        }
      else
        render json: {
          status: 'error',
          message: 'Must specify either cache type or trigger type',
          available_cache_types: CacheManager::CACHE_PREFIXES.keys,
          available_triggers: [:keyword_change, :user_data_change, :comment_change, :metrics_recalculation]
        }, status: :bad_request
      end
    rescue => e
      Rails.logger.error "Cache invalidation failed: #{e.message}"
      render json: {
        status: 'error',
        message: 'Cache invalidation failed'
      }, status: :internal_server_error
    end
  end

  # GET /api/cache/config
  def configuration
    render json: {
      status: 'success',
      data: {
        cache_store: Rails.cache.class.name,
        environment: Rails.env,
        ttl_strategies: CacheManager::TTL_STRATEGIES,
        size_limits: CacheManager::SIZE_LIMITS.transform_values { |size| "#{size / 1.megabyte}MB" },
        cache_prefixes: CacheManager::CACHE_PREFIXES
      }
    }
  end

  # POST /api/cache/benchmark
  def benchmark
    iterations = params[:iterations]&.to_i || 1000

    if iterations > 10000
      return render json: {
        status: 'error',
        message: 'Maximum 10,000 iterations allowed'
      }, status: :bad_request
    end

    begin
      results = CacheMonitor.benchmark_operations(iterations: iterations)

      render json: {
        status: 'success',
        data: results
      }
    rescue => e
      Rails.logger.error "Cache benchmark failed: #{e.message}"
      render json: {
        status: 'error',
        message: 'Benchmark failed'
      }, status: :internal_server_error
    end
  end

  # POST /api/cache/reset_stats
  def reset_stats
    CacheManager.reset_stats

    render json: {
      status: 'success',
      message: 'Cache statistics reset'
    }
  end

  # GET /api/cache/circuit_breakers
  def circuit_breakers
    circuit_breaker_status = {
      jsonplaceholder: {
        state: CircuitBreaker.for_service(:jsonplaceholder).state,
        failure_count: CircuitBreaker.for_service(:jsonplaceholder).failure_count,
        success_count: CircuitBreaker.for_service(:jsonplaceholder).success_count
      },
      libretranslate: {
        state: CircuitBreaker.for_service(:libretranslate).state,
        failure_count: CircuitBreaker.for_service(:libretranslate).failure_count,
        success_count: CircuitBreaker.for_service(:libretranslate).success_count
      }
    }

    render json: {
      status: 'success',
      data: circuit_breaker_status
    }
  end

  # POST /api/cache/circuit_breakers/:service/reset
  def reset_circuit_breaker
    service_name = params[:service]&.to_sym

    if [:jsonplaceholder, :libretranslate].include?(service_name)
      CircuitBreaker.for_service(service_name).reset!
      render json: {
        status: 'success',
        message: "Circuit breaker reset for #{service_name}"
      }
    else
      render json: {
        status: 'error',
        message: "Invalid service name. Valid services: jsonplaceholder, libretranslate"
      }, status: :bad_request
    end
  end

  private

  def invalidation_options
    options = {}
    options[:user_id] = params[:user_id] if params[:user_id]
    options[:text_hash] = params[:text_hash] if params[:text_hash]
    options
  end
end
