class MetricsRecalculationJob < ApplicationJob
  queue_as :default

  # Retry configuration for failed jobs
  retry_on StandardError, wait: 10.seconds, attempts: 3

  # Discard job after all retries are exhausted
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.error "MetricsRecalculationJob discarded - Deserialization error: #{error.message}"
  end

  def perform(user_id_or_trigger = nil, trigger_type = 'manual')
    Rails.logger.info "Starting MetricsRecalculationJob - trigger: #{trigger_type}, user_id: #{user_id_or_trigger}"

    begin
      metrics_service = MetricsService.new

      case trigger_type
      when 'keyword_change'
        # Recalculate all metrics when keywords change
        Rails.logger.info "Recalculating all metrics due to keyword change"
        recalculate_all_metrics(metrics_service)

      when 'user_import_completed'
        # Recalculate metrics for specific user and group metrics
        user_id = user_id_or_trigger
        Rails.logger.info "Recalculating metrics for user #{user_id} after import completion"
        recalculate_user_and_group_metrics(metrics_service, user_id)

      when 'manual'
        # Manual recalculation - recalculate everything
        Rails.logger.info "Manual recalculation of all metrics"
        recalculate_all_metrics(metrics_service)

      when 'user_specific'
        # Recalculate metrics for a specific user only
        user_id = user_id_or_trigger
        Rails.logger.info "Recalculating metrics for specific user: #{user_id}"
        recalculate_user_metrics(metrics_service, user_id)

      else
        Rails.logger.warn "Unknown trigger type: #{trigger_type}, defaulting to full recalculation"
        recalculate_all_metrics(metrics_service)
      end

      Rails.logger.info "MetricsRecalculationJob completed successfully for trigger: #{trigger_type}"

    rescue => e
      Rails.logger.error "MetricsRecalculationJob failed for trigger #{trigger_type}: #{e.message}"
      raise # Re-raise to trigger retry logic
    end
  end

  # Class method for easy triggering from other parts of the application
  def self.trigger_keyword_change_recalculation
    perform_later(nil, 'keyword_change')
  end

  def self.trigger_user_import_completion(user_id)
    perform_later(user_id, 'user_import_completed')
  end

  def self.trigger_manual_recalculation
    perform_later(nil, 'manual')
  end

  def self.trigger_user_specific_recalculation(user_id)
    perform_later(user_id, 'user_specific')
  end

  private

  def recalculate_all_metrics(metrics_service)
    Rails.logger.info "Starting full metrics recalculation"

    start_time = Time.current

    # Use the service method that handles everything
    metrics_service.recalculate_all_metrics

    end_time = Time.current
    duration = (end_time - start_time).round(2)

    Rails.logger.info "Full metrics recalculation completed in #{duration} seconds"
  end

  def recalculate_user_and_group_metrics(metrics_service, user_id)
    Rails.logger.info "Recalculating metrics for user #{user_id} and group metrics"

    start_time = Time.current

    begin
      # Recalculate metrics for the specific user
      user_metrics = metrics_service.calculate_user_metrics(user_id)
      Rails.logger.debug "User #{user_id} metrics recalculated: #{user_metrics[:total_comments]} comments"

      # Recalculate group metrics (since a new user was added/updated)
      group_metrics = metrics_service.calculate_group_metrics
      Rails.logger.debug "Group metrics recalculated: #{group_metrics[:total_users]} users, #{group_metrics[:total_comments]} comments"

      end_time = Time.current
      duration = (end_time - start_time).round(2)

      Rails.logger.info "User and group metrics recalculation completed in #{duration} seconds"

    rescue => e
      Rails.logger.error "Failed to recalculate metrics for user #{user_id}: #{e.message}"
      raise
    end
  end

  def recalculate_user_metrics(metrics_service, user_id)
    Rails.logger.info "Recalculating metrics for user #{user_id} only"

    start_time = Time.current

    begin
      # Verify user exists
      user = User.find(user_id)

      # Recalculate metrics for the specific user
      user_metrics = metrics_service.calculate_user_metrics(user_id)
      Rails.logger.debug "User #{user_id} (#{user.name}) metrics recalculated: #{user_metrics[:total_comments]} comments"

      end_time = Time.current
      duration = (end_time - start_time).round(2)

      Rails.logger.info "User-specific metrics recalculation completed in #{duration} seconds"

    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "User #{user_id} not found for metrics recalculation"
      raise
    rescue => e
      Rails.logger.error "Failed to recalculate metrics for user #{user_id}: #{e.message}"
      raise
    end
  end
end
