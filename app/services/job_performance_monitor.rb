class JobPerformanceMonitor
  # Performance thresholds (in seconds)
  PERFORMANCE_THRESHOLDS = {
    'ImportJob' => 300,        # 5 minutes
    'TranslationJob' => 60,    # 1 minute
    'MetricsRecalculationJob' => 120, # 2 minutes
    'CacheWarmingJob' => 30    # 30 seconds
  }.freeze

  # Memory usage thresholds (in MB)
  MEMORY_THRESHOLDS = {
    'ImportJob' => 500,        # 500 MB
    'TranslationJob' => 100,   # 100 MB
    'MetricsRecalculationJob' => 200, # 200 MB
    'CacheWarmingJob' => 50    # 50 MB
  }.freeze

  class << self
    def monitor_job(job_class, job_id = nil)
      job_name = job_class.to_s
      start_time = Time.current
      start_memory = current_memory_usage

      Rails.logger.info_with_context(
        "Job started: #{job_name}",
        {
          job_class: job_name,
          job_id: job_id,
          start_memory_mb: start_memory
        }
      )

      result = yield

      end_time = Time.current
      end_memory = current_memory_usage
      duration = end_time - start_time
      memory_used = end_memory - start_memory

      # Log performance metrics
      log_performance_metrics(job_name, job_id, duration, memory_used, start_memory, end_memory)

      # Check for performance issues
      check_performance_thresholds(job_name, job_id, duration, memory_used)

      result

    rescue => error
      end_time = Time.current
      duration = end_time - start_time

      Rails.logger.error_with_context(
        "Job failed: #{job_name}",
        error,
        {
          job_class: job_name,
          job_id: job_id,
          duration_seconds: duration.round(2),
          failure_point: 'execution'
        }
      )

      # Record job failure metrics
      record_job_failure(job_name, job_id, error, duration)

      raise
    end

    def record_job_start(job_class, job_id, arguments = {})
      job_name = job_class.to_s

      Rails.logger.info_with_context(
        "Job queued: #{job_name}",
        {
          job_class: job_name,
          job_id: job_id,
          arguments: sanitize_arguments(arguments),
          queue_time: Time.current.iso8601
        }
      )

      # Store job start time in cache for queue time calculation
      CacheManager.write("job_start:#{job_id}", Time.current.to_f, cache_type: :job_metrics)
    end

    def record_job_completion(job_class, job_id, success: true, error: nil)
      job_name = job_class.to_s
      queue_start_time = CacheManager.read("job_start:#{job_id}", cache_type: :job_metrics)

      queue_duration = if queue_start_time
        Time.current.to_f - queue_start_time
      else
        nil
      end

      if success
        Rails.logger.info_with_context(
          "Job completed successfully: #{job_name}",
          {
            job_class: job_name,
            job_id: job_id,
            queue_duration_seconds: queue_duration&.round(2),
            completion_time: Time.current.iso8601
          }
        )
      else
        Rails.logger.error_with_context(
          "Job completed with failure: #{job_name}",
          error,
          {
            job_class: job_name,
            job_id: job_id,
            queue_duration_seconds: queue_duration&.round(2),
            completion_time: Time.current.iso8601
          }
        )
      end

      # Clean up cache
      CacheManager.delete("job_start:#{job_id}", cache_type: :job_metrics)
    end

    private

    def log_performance_metrics(job_name, job_id, duration, memory_used, start_memory, end_memory)
      Rails.logger.info_with_context(
        "Job performance metrics: #{job_name}",
        {
          job_class: job_name,
          job_id: job_id,
          duration_seconds: duration.round(2),
          memory_used_mb: memory_used.round(2),
          start_memory_mb: start_memory.round(2),
          end_memory_mb: end_memory.round(2),
          performance_status: performance_status(job_name, duration, memory_used)
        }
      )
    end

    def check_performance_thresholds(job_name, job_id, duration, memory_used)
      duration_threshold = PERFORMANCE_THRESHOLDS[job_name]
      memory_threshold = MEMORY_THRESHOLDS[job_name]

      if duration_threshold && duration > duration_threshold
        Rails.logger.warn_with_context(
          "Job exceeded duration threshold: #{job_name}",
          {
            job_class: job_name,
            job_id: job_id,
            duration_seconds: duration.round(2),
            threshold_seconds: duration_threshold,
            performance_issue: 'slow_execution'
          }
        )

        # Trigger alert for slow jobs
        CriticalErrorNotifier.notify_performance_issue(
          job_name,
          job_id,
          'slow_execution',
          { duration: duration, threshold: duration_threshold }
        )
      end

      if memory_threshold && memory_used > memory_threshold
        Rails.logger.warn_with_context(
          "Job exceeded memory threshold: #{job_name}",
          {
            job_class: job_name,
            job_id: job_id,
            memory_used_mb: memory_used.round(2),
            threshold_mb: memory_threshold,
            performance_issue: 'high_memory_usage'
          }
        )

        # Trigger alert for memory-intensive jobs
        CriticalErrorNotifier.notify_performance_issue(
          job_name,
          job_id,
          'high_memory_usage',
          { memory_used: memory_used, threshold: memory_threshold }
        )
      end
    end

    def record_job_failure(job_name, job_id, error, duration)
      failure_data = {
        job_class: job_name,
        job_id: job_id,
        error_class: error.class.name,
        error_message: error.message,
        duration_seconds: duration.round(2),
        failure_time: Time.current.iso8601
      }

      # Store failure data for analysis
      CacheManager.write(
        "job_failure:#{job_id}",
        failure_data,
        cache_type: :job_metrics,
        expires_in: 24.hours
      )

      # Increment failure counter
      failure_key = "job_failures:#{job_name}:#{Date.current}"
      current_failures = CacheManager.read(failure_key, cache_type: :job_metrics) || 0
      CacheManager.write(
        failure_key,
        current_failures + 1,
        cache_type: :job_metrics,
        expires_in: 25.hours
      )

      # Alert if failure rate is high
      if current_failures >= 5 # 5 failures per day threshold
        CriticalErrorNotifier.notify_high_failure_rate(job_name, current_failures + 1)
      end
    end

    def performance_status(job_name, duration, memory_used)
      duration_threshold = PERFORMANCE_THRESHOLDS[job_name]
      memory_threshold = MEMORY_THRESHOLDS[job_name]

      issues = []
      issues << 'slow' if duration_threshold && duration > duration_threshold
      issues << 'memory_intensive' if memory_threshold && memory_used > memory_threshold

      issues.any? ? issues.join(',') : 'normal'
    end

    def current_memory_usage
      # Get current process memory usage in MB
      if RUBY_PLATFORM.include?('linux')
        `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
      else
        # Fallback for other platforms - use Ruby's memory info if available
        begin
          GC.stat[:heap_allocated_pages] * GC::INTERNAL_CONSTANTS[:HEAP_PAGE_SIZE] / (1024 * 1024)
        rescue
          0.0
        end
      end
    rescue
      0.0
    end

    def sanitize_arguments(arguments)
      # Remove sensitive data from job arguments before logging
      return arguments unless arguments.is_a?(Hash) || arguments.is_a?(Array)

      case arguments
      when Hash
        arguments.deep_dup.tap do |sanitized|
          %w[password token api_key secret].each do |sensitive_key|
            sanitized.delete(sensitive_key)
            sanitized.delete(sensitive_key.to_sym)
          end
        end
      when Array
        arguments.map { |arg| arg.is_a?(String) && arg.length > 100 ? "#{arg[0..100]}..." : arg }
      else
        arguments
      end
    rescue
      '[sanitization_failed]'
    end
  end
end
