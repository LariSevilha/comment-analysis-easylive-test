class ApplicationJob < ActiveJob::Base
  # Configure Solid Queue as the adapter (this is set in config/environments/*.rb)
  # queue_adapter :solid_queue

  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error "Job discarded due to deserialization error: #{error.message}"
  end

  # Enhanced job monitoring with performance tracking
  before_enqueue do |job|
    JobPerformanceMonitor.record_job_start(job.class, job.job_id, job.arguments)
  end

  around_perform do |job, block|
    # Set job context for logging
    RequestContext.set(
      job_id: job.job_id,
      job_class: job.class.name,
      job_arguments: job.arguments
    )

    JobPerformanceMonitor.monitor_job(job.class, job.job_id) do
      block.call
    end
  rescue => error
    JobPerformanceMonitor.record_job_completion(job.class, job.job_id, success: false, error: error)
    raise
  else
    JobPerformanceMonitor.record_job_completion(job.class, job.job_id, success: true)
  ensure
    RequestContext.clear
  end

  # Individual jobs should handle their own specific errors
  # Global rescue_from can interfere with job-specific error handling
end
