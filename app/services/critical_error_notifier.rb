class CriticalErrorNotifier
  # Error severity levels
  SEVERITY_LEVELS = {
    low: 1,
    medium: 2,
    high: 3,
    critical: 4
  }.freeze

  # Rate limiting for alerts (prevent spam)
  ALERT_RATE_LIMITS = {
    critical: 1.minute,   # Max 1 critical alert per minute
    high: 5.minutes,      # Max 1 high alert per 5 minutes
    medium: 15.minutes,   # Max 1 medium alert per 15 minutes
    low: 1.hour           # Max 1 low alert per hour
  }.freeze

  class << self
    def notify(error, request = nil, severity: :high)
      return unless should_send_alert?(error, severity)

      alert_data = build_alert_data(error, request, severity)

      # Log the alert
      Rails.logger.error_with_context(
        "Critical error alert triggered",
        error,
        alert_data.merge(alert_severity: severity)
      )

      # Send alert through configured channels
      send_alert(alert_data, severity)

      # Record alert for rate limiting
      record_alert(error, severity)

    rescue => alert_error
      # Don't let alerting errors break the application
      Rails.logger.error "Failed to send critical error alert: #{alert_error.message}"
    end

    def notify_performance_issue(job_name, job_id, issue_type, metrics, severity: :medium)
      return unless should_send_performance_alert?(job_name, issue_type, severity)

      alert_data = {
        alert_type: 'performance_issue',
        job_name: job_name,
        job_id: job_id,
        issue_type: issue_type,
        metrics: metrics,
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        hostname: Socket.gethostname
      }

      Rails.logger.warn_with_context(
        "Performance issue alert: #{job_name}",
        alert_data.merge(alert_severity: severity)
      )

      send_alert(alert_data, severity)
      record_performance_alert(job_name, issue_type, severity)

    rescue => alert_error
      Rails.logger.error "Failed to send performance alert: #{alert_error.message}"
    end

    def notify_high_failure_rate(job_name, failure_count, severity: :high)
      return unless should_send_failure_rate_alert?(job_name, severity)

      alert_data = {
        alert_type: 'high_failure_rate',
        job_name: job_name,
        failure_count: failure_count,
        time_period: '24 hours',
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        hostname: Socket.gethostname
      }

      Rails.logger.error_with_context(
        "High failure rate alert: #{job_name}",
        alert_data.merge(alert_severity: severity)
      )

      send_alert(alert_data, severity)
      record_failure_rate_alert(job_name, severity)

    rescue => alert_error
      Rails.logger.error "Failed to send failure rate alert: #{alert_error.message}"
    end

    def notify_circuit_breaker_open(service_name, failure_count, severity: :high)
      alert_data = {
        alert_type: 'circuit_breaker_open',
        service_name: service_name,
        failure_count: failure_count,
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        hostname: Socket.gethostname
      }

      Rails.logger.error_with_context(
        "Circuit breaker opened: #{service_name}",
        alert_data.merge(alert_severity: severity)
      )

      send_alert(alert_data, severity)

    rescue => alert_error
      Rails.logger.error "Failed to send circuit breaker alert: #{alert_error.message}"
    end

    private

    def should_send_alert?(error, severity)
      # Don't alert on certain expected errors
      return false if ignorable_error?(error)

      # Check rate limiting
      !rate_limited?(error_key(error), severity)
    end

    def should_send_performance_alert?(job_name, issue_type, severity)
      alert_key = "performance:#{job_name}:#{issue_type}"
      !rate_limited?(alert_key, severity)
    end

    def should_send_failure_rate_alert?(job_name, severity)
      alert_key = "failure_rate:#{job_name}"
      !rate_limited?(alert_key, severity)
    end

    def ignorable_error?(error)
      ignorable_classes = [
        'ActiveRecord::RecordNotFound',
        'ActionController::ParameterMissing',
        'ActionController::BadRequest'
      ]

      ignorable_classes.include?(error.class.name)
    end

    def rate_limited?(alert_key, severity)
      rate_limit_window = ALERT_RATE_LIMITS[severity] || 1.hour
      last_alert_key = "alert_rate_limit:#{alert_key}"

      last_alert_time = CacheManager.read(last_alert_key, cache_type: :alerts)

      if last_alert_time
        Time.current - Time.parse(last_alert_time) < rate_limit_window
      else
        false
      end
    end

    def record_alert(error, severity)
      alert_key = error_key(error)
      rate_limit_key = "alert_rate_limit:#{alert_key}"

      CacheManager.write(
        rate_limit_key,
        Time.current.iso8601,
        cache_type: :alerts,
        expires_in: ALERT_RATE_LIMITS[severity] || 1.hour
      )
    end

    def record_performance_alert(job_name, issue_type, severity)
      alert_key = "performance:#{job_name}:#{issue_type}"
      rate_limit_key = "alert_rate_limit:#{alert_key}"

      CacheManager.write(
        rate_limit_key,
        Time.current.iso8601,
        cache_type: :alerts,
        expires_in: ALERT_RATE_LIMITS[severity] || 1.hour
      )
    end

    def record_failure_rate_alert(job_name, severity)
      alert_key = "failure_rate:#{job_name}"
      rate_limit_key = "alert_rate_limit:#{alert_key}"

      CacheManager.write(
        rate_limit_key,
        Time.current.iso8601,
        cache_type: :alerts,
        expires_in: ALERT_RATE_LIMITS[severity] || 1.hour
      )
    end

    def build_alert_data(error, request, severity)
      {
        alert_type: 'application_error',
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(15),
        severity: severity,
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        hostname: Socket.gethostname,
        request_data: request ? extract_request_data(request) : nil,
        context: RequestContext.get
      }
    end

    def extract_request_data(request)
      {
        method: request.method,
        path: request.path,
        ip: request.remote_ip,
        user_agent: request.user_agent,
        request_id: request.request_id
      }
    rescue
      { error: 'Failed to extract request data' }
    end

    def send_alert(alert_data, severity)
      # Send to configured alert channels
      alert_channels = configured_alert_channels(severity)

      alert_channels.each do |channel|
        case channel
        when :log
          # Already logged above, but ensure it's marked as alert
          Rails.logger.error "[ALERT] #{alert_data[:alert_type]}: #{alert_data.to_json}"
        when :email
          send_email_alert(alert_data, severity)
        when :slack
          send_slack_alert(alert_data, severity)
        when :webhook
          send_webhook_alert(alert_data, severity)
        end
      end
    end

    def configured_alert_channels(severity)
      # Default to logging for all severities
      channels = [:log]

      # Add additional channels based on configuration and severity
      if Rails.env.production?
        case severity
        when :critical
          channels += [:email, :slack, :webhook].select { |c| channel_configured?(c) }
        when :high
          channels += [:email, :slack].select { |c| channel_configured?(c) }
        when :medium
          channels += [:slack].select { |c| channel_configured?(c) } if channel_configured?(:slack)
        end
      end

      channels.uniq
    end

    def channel_configured?(channel)
      case channel
      when :email
        ENV['ALERT_EMAIL_TO'].present?
      when :slack
        ENV['SLACK_WEBHOOK_URL'].present?
      when :webhook
        ENV['ALERT_WEBHOOK_URL'].present?
      else
        false
      end
    end

    def send_email_alert(alert_data, severity)
      return unless ENV['ALERT_EMAIL_TO'].present?

      # Queue email alert job (implement AlertMailerJob if needed)
      Rails.logger.info "Email alert would be sent to: #{ENV['ALERT_EMAIL_TO']}"
      # AlertMailerJob.perform_later(alert_data, severity)
    end

    def send_slack_alert(alert_data, severity)
      return unless ENV['SLACK_WEBHOOK_URL'].present?

      slack_payload = {
        text: "🚨 #{severity.upcase} Alert: #{alert_data[:alert_type]}",
        attachments: [
          {
            color: severity_color(severity),
            fields: [
              {
                title: "Error",
                value: "#{alert_data[:error_class]}: #{alert_data[:error_message]}",
                short: false
              },
              {
                title: "Environment",
                value: alert_data[:environment],
                short: true
              },
              {
                title: "Hostname",
                value: alert_data[:hostname],
                short: true
              },
              {
                title: "Timestamp",
                value: alert_data[:timestamp],
                short: true
              }
            ]
          }
        ]
      }

      # Queue Slack alert job (implement SlackAlertJob if needed)
      Rails.logger.info "Slack alert would be sent: #{slack_payload.to_json}"
      # SlackAlertJob.perform_later(slack_payload)
    end

    def send_webhook_alert(alert_data, severity)
      return unless ENV['ALERT_WEBHOOK_URL'].present?

      # Queue webhook alert job (implement WebhookAlertJob if needed)
      Rails.logger.info "Webhook alert would be sent to: #{ENV['ALERT_WEBHOOK_URL']}"
      # WebhookAlertJob.perform_later(alert_data, severity)
    end

    def severity_color(severity)
      case severity
      when :critical
        'danger'
      when :high
        'warning'
      when :medium
        'good'
      when :low
        '#439FE0'
      else
        'good'
      end
    end

    def error_key(error)
      "#{error.class.name}:#{Digest::MD5.hexdigest(error.message)}"
    end
  end
end
