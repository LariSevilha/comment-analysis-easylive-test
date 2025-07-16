class CircuitBreaker
  # Circuit breaker states
  STATES = {
    closed: 'closed',       # Normal operation
    open: 'open',          # Circuit is open, requests fail fast
    half_open: 'half_open' # Testing if service is back
  }.freeze

  # Default configuration
  DEFAULT_CONFIG = {
    failure_threshold: 5,      # Number of failures before opening
    recovery_timeout: 60,      # Seconds before trying half-open
    success_threshold: 3,      # Successes needed to close from half-open
    timeout: 30,              # Request timeout in seconds
    exceptions: [             # Exceptions that count as failures
      Timeout::Error,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNREFUSED,
      SocketError,
      HTTParty::Error
    ]
  }.freeze

  class CircuitOpenError < StandardError; end
  class CircuitHalfOpenError < StandardError; end

  def initialize(name, config = {})
    @name = name
    @config = DEFAULT_CONFIG.merge(config)
    @state_key = "circuit_breaker:#{@name}:state"
    @failure_count_key = "circuit_breaker:#{@name}:failures"
    @last_failure_key = "circuit_breaker:#{@name}:last_failure"
    @success_count_key = "circuit_breaker:#{@name}:successes"
  end

  def call
    case current_state
    when STATES[:open]
      handle_open_circuit
    when STATES[:half_open]
      handle_half_open_circuit { yield }
    else # closed
      handle_closed_circuit { yield }
    end
  end

  def state
    current_state
  end

  def failure_count
    CacheManager.read(@failure_count_key, cache_type: :circuit_breaker) || 0
  end

  def success_count
    CacheManager.read(@success_count_key, cache_type: :circuit_breaker) || 0
  end

  def reset!
    CacheManager.delete(@state_key, cache_type: :circuit_breaker)
    CacheManager.delete(@failure_count_key, cache_type: :circuit_breaker)
    CacheManager.delete(@last_failure_key, cache_type: :circuit_breaker)
    CacheManager.delete(@success_count_key, cache_type: :circuit_breaker)

    Rails.logger.info_with_context(
      "Circuit breaker reset: #{@name}",
      { circuit_breaker: @name, action: 'reset' }
    )
  end

  def force_open!
    set_state(STATES[:open])

    # Set a fake last failure time to prevent immediate transition to half-open
    CacheManager.write(
      @last_failure_key,
      {
        time: Time.current.iso8601,
        error: 'ForcedOpen',
        message: 'Circuit breaker was manually forced open'
      },
      cache_type: :circuit_breaker,
      expires_in: @config[:recovery_timeout] * 2
    )

    Rails.logger.warn_with_context(
      "Circuit breaker forced open: #{@name}",
      { circuit_breaker: @name, action: 'force_open' }
    )
  end

  def force_close!
    reset!
    set_state(STATES[:closed])
    Rails.logger.info_with_context(
      "Circuit breaker forced closed: #{@name}",
      { circuit_breaker: @name, action: 'force_close' }
    )
  end

  private

  def current_state
    state = CacheManager.read(@state_key, cache_type: :circuit_breaker)
    return STATES[:closed] unless state

    # Check if we should transition from open to half-open
    if state == STATES[:open] && should_attempt_reset?
      set_state(STATES[:half_open])
      return STATES[:half_open]
    end

    state
  end

  def handle_closed_circuit
    begin
      result = execute_with_timeout { yield }
      record_success
      result
    rescue => error
      if failure_exception?(error)
        record_failure(error)
        current_failures = failure_count

        if current_failures >= @config[:failure_threshold]
          open_circuit
        end
      end
      raise
    end
  end

  def handle_open_circuit
    Rails.logger.warn_with_context(
      "Circuit breaker is open: #{@name}",
      {
        circuit_breaker: @name,
        state: 'open',
        failure_count: failure_count,
        last_failure: last_failure_time
      }
    )

    raise CircuitOpenError, "Circuit breaker is open for #{@name}"
  end

  def handle_half_open_circuit
    begin
      result = execute_with_timeout { yield }
      record_success

      if success_count >= @config[:success_threshold]
        close_circuit
      end

      result
    rescue => error
      if failure_exception?(error)
        record_failure(error)
        open_circuit
      end
      raise
    end
  end

  def execute_with_timeout
    Timeout.timeout(@config[:timeout]) do
      yield
    end
  end

  def record_success
    # Increment success count
    current_successes = success_count
    CacheManager.write(
      @success_count_key,
      current_successes + 1,
      cache_type: :circuit_breaker,
      expires_in: @config[:recovery_timeout] * 2
    )

    Rails.logger.debug "Circuit breaker success recorded: #{@name} (#{current_successes + 1})"
  end

  def record_failure(error)
    # Increment failure count
    current_failures = failure_count
    new_count = current_failures + 1

    CacheManager.write(
      @failure_count_key,
      new_count,
      cache_type: :circuit_breaker,
      expires_in: @config[:recovery_timeout] * 2
    )

    # Record last failure time and error
    CacheManager.write(
      @last_failure_key,
      {
        time: Time.current.iso8601,
        error: error.class.name,
        message: error.message
      },
      cache_type: :circuit_breaker,
      expires_in: @config[:recovery_timeout] * 2
    )

    Rails.logger.warn_with_context(
      "Circuit breaker failure recorded: #{@name}",
      {
        circuit_breaker: @name,
        failure_count: new_count,
        error_class: error.class.name,
        error_message: error.message
      }
    )
  end

  def open_circuit
    set_state(STATES[:open])

    Rails.logger.error_with_context(
      "Circuit breaker opened: #{@name}",
      nil,
      {
        circuit_breaker: @name,
        failure_count: failure_count,
        threshold: @config[:failure_threshold]
      }
    )

    # Notify about circuit breaker opening
    CriticalErrorNotifier.notify_circuit_breaker_open(@name, failure_count)
  end

  def close_circuit
    # Reset counters but keep state as closed
    CacheManager.delete(@failure_count_key, cache_type: :circuit_breaker)
    CacheManager.delete(@success_count_key, cache_type: :circuit_breaker)
    CacheManager.delete(@last_failure_key, cache_type: :circuit_breaker)
    set_state(STATES[:closed])

    Rails.logger.info_with_context(
      "Circuit breaker closed: #{@name}",
      {
        circuit_breaker: @name,
        success_count: success_count
      }
    )
  end

  def set_state(state)
    CacheManager.write(
      @state_key,
      state,
      cache_type: :circuit_breaker,
      expires_in: @config[:recovery_timeout] * 3
    )
  end

  def should_attempt_reset?
    last_failure_data = CacheManager.read(@last_failure_key, cache_type: :circuit_breaker)
    return true unless last_failure_data

    last_failure_time = Time.parse(last_failure_data[:time])
    Time.current - last_failure_time >= @config[:recovery_timeout]
  rescue
    true # If we can't parse the time, allow reset attempt
  end

  def last_failure_time
    last_failure_data = CacheManager.read(@last_failure_key, cache_type: :circuit_breaker)
    last_failure_data ? last_failure_data[:time] : nil
  end

  def failure_exception?(error)
    @config[:exceptions].any? { |exception_class| error.is_a?(exception_class) }
  end

  class << self
    # Factory method to create circuit breakers for common services
    def for_service(service_name, config = {})
      service_configs = {
        jsonplaceholder: {
          failure_threshold: 3,
          recovery_timeout: 30,
          timeout: 15
        },
        libretranslate: {
          failure_threshold: 5,
          recovery_timeout: 60,
          timeout: 30,
          exceptions: DEFAULT_CONFIG[:exceptions] + [
            TranslationService::APIError,
            TranslationService::RateLimitError
          ]
        }
      }

      service_config = service_configs[service_name.to_sym] || {}
      new(service_name.to_s, service_config.merge(config))
    end

    # Get or create circuit breaker instance
    def get(name, config = {})
      @circuit_breakers ||= {}
      @circuit_breakers[name] ||= new(name, config)
    end
  end
end
