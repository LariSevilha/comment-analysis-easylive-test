require 'test_helper'

class ErrorHandlingTest < ActiveSupport::TestCase
  def setup
    # Enable caching for tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @circuit_breaker = CircuitBreaker.new('test_service')
    @original_logger = Rails.logger
    @log_output = StringIO.new
    @test_logger = Logger.new(@log_output)
    @test_logger.formatter = StructuredLogFormatter.new
    Rails.logger = @test_logger
  end

  def teardown
    Rails.logger = @original_logger
    Rails.cache = @original_cache_store
    @circuit_breaker.reset!
    RequestContext.clear
  end

  test "circuit breaker opens after threshold failures" do
    assert_equal 'closed', @circuit_breaker.state

    # Simulate failures up to threshold
    5.times do
      assert_raises(Timeout::Error) do
        @circuit_breaker.call { raise Timeout::Error, "Simulated timeout" }
      end
    end

    # Circuit should now be open
    assert_equal 'open', @circuit_breaker.state
    assert_equal 5, @circuit_breaker.failure_count
  end

  test "circuit breaker fails fast when open" do
    @circuit_breaker.force_open!

    assert_raises(CircuitBreaker::CircuitOpenError) do
      @circuit_breaker.call { "This should not execute" }
    end
  end

  test "request context is properly set and cleared" do
    context_data = {
      request_id: 'test-123',
      user_id: 456,
      action: 'test_action'
    }

    RequestContext.set(context_data)

    assert_equal 'test-123', RequestContext.request_id
    assert_equal 456, RequestContext.user_id
    assert_equal context_data.merge(timestamp: RequestContext.get[:timestamp]), RequestContext.get

    RequestContext.clear
    assert_empty RequestContext.get
  end

  test "critical error notifier respects rate limiting" do
    error = StandardError.new("Test error")

    # First alert should go through
    assert_nothing_raised do
      CriticalErrorNotifier.notify(error, severity: :high)
    end

    # Second alert within rate limit should be blocked
    assert_nothing_raised do
      CriticalErrorNotifier.notify(error, severity: :high)
    end

    # Check that rate limiting was applied (second alert should be blocked)
    log_content = @log_output.string
    alert_count = log_content.scan(/Critical error alert triggered/).count
    assert_equal 1, alert_count, "Expected only one alert due to rate limiting"
  end

  test "job performance monitor tracks execution time" do
    job_class = 'TestJob'
    job_id = 'test-job-123'

    execution_time = nil

    JobPerformanceMonitor.monitor_job(job_class, job_id) do
      sleep(0.1) # Simulate work
      execution_time = Time.current
    end

    log_content = @log_output.string
    assert_includes log_content, "Job started: #{job_class}"
    assert_includes log_content, "Job performance metrics: #{job_class}"
    assert_includes log_content, "duration_seconds"
  end

  test "structured logging includes context" do
    RequestContext.set(
      request_id: 'test-456',
      user_id: 789
    )

    Rails.logger.info_with_context("Test message", { additional: "data" })

    log_content = @log_output.string
    log_entry = JSON.parse(log_content.lines.last)

    assert_equal "Test message", log_entry["message"]
    assert_equal "test-456", log_entry["context"]["request_id"]
    assert_equal 789, log_entry["context"]["user_id"]
    assert_equal "data", log_entry["additional"]
  end

  test "cache manager supports new cache types" do
    # Test circuit breaker cache
    CircuitBreaker.for_service(:test_service).reset!

    # Test job metrics cache
    test_data = { job_id: 'test', duration: 1.5 }
    assert CacheManager.write('test_job_metrics', test_data, cache_type: :job_metrics)

    cached_data = CacheManager.read('test_job_metrics', cache_type: :job_metrics)
    assert_equal test_data, cached_data

    # Test alerts cache
    alert_data = { alert_type: 'test', timestamp: Time.current.iso8601 }
    assert CacheManager.write('test_alert', alert_data, cache_type: :alerts)

    cached_alert = CacheManager.read('test_alert', cache_type: :alerts)
    assert_equal alert_data, cached_alert
  end
end
