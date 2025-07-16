# frozen_string_literal: true

# Cache Configuration for Comment Analysis Pipeline
# This initializer configures Solid Cache with optimized settings for different data types

Rails.application.configure do
  # Enhanced Solid Cache configuration
  if Rails.env.production?
    # Production cache configuration
    config.cache_store = :solid_cache_store, {
      database: :cache,
      store_options: {
        max_age: 1.week.to_i,           # Global max age
        max_size: 512.megabytes,        # Increased cache size for production
        namespace: Rails.env,
        compress: true,                 # Enable compression for large values
        compress_threshold: 1.kilobyte, # Compress values larger than 1KB
        expires_in: 1.hour,            # Default TTL
        race_condition_ttl: 5.seconds   # Prevent cache stampede
      }
    }
  elsif Rails.env.development?
    # Development cache configuration
    if Rails.root.join("tmp/caching-dev.txt").exist?
      config.cache_store = :solid_cache_store, {
        database: :cache,
        store_options: {
          max_age: 1.day.to_i,
          max_size: 128.megabytes,      # Smaller cache size for development
          namespace: Rails.env,
          compress: false,              # Disable compression for faster dev cycles
          expires_in: 30.minutes,       # Shorter TTL for development
          race_condition_ttl: 2.seconds
        }
      }
    else
      config.cache_store = :null_store
    end
  else
    # Test environment - use memory store for faster tests
    config.cache_store = :memory_store, {
      size: 32.megabytes,
      expires_in: 10.minutes
    }
  end
end

# Initialize cache monitoring after Rails loads
Rails.application.config.after_initialize do
  # Start cache monitoring in production
  if Rails.env.production?
    # Schedule periodic cache monitoring
    Thread.new do
      loop do
        sleep 30.minutes
        begin
          CacheMonitor.log_periodic_stats(:medium)
        rescue => e
          Rails.logger.error "Cache monitoring error: #{e.message}"
        end
      end
    end
  end

  # Warm cache on application startup in production
  if Rails.env.production? && defined?(CacheWarmingJob)
    begin
      # Schedule initial cache warming after a short delay
      CacheWarmingJob.set(wait: 30.seconds).perform_later('full')
      Rails.logger.info "Scheduled initial cache warming"
    rescue => e
      Rails.logger.warn "Failed to schedule cache warming: #{e.message}"
    end
  end

  # Log cache configuration
  Rails.logger.info "Cache store configured: #{Rails.cache.class.name}"
  Rails.logger.info "Cache configuration: #{Rails.application.config.cache_store}"
end
