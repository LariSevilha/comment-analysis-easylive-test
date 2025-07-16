class CommentAnalysisService
  # Custom exceptions
  class AnalysisError < StandardError; end
  class InvalidUsernameError < AnalysisError; end
  class PipelineError < AnalysisError; end

  def initialize
    @logger = Rails.logger
  end

  # Main method to start the complete analysis pipeline for a username
  def analyze_user_comments(username)
    raise InvalidUsernameError, "Username cannot be blank" if username.blank?

    @logger.info "Starting comment analysis pipeline for username: #{username}"

    begin
      # Create job tracker for progress monitoring
      job_tracker = create_job_tracker(username)

      # Log pipeline initiation
      log_pipeline_event('pipeline_started', {
        username: username,
        job_id: job_tracker.job_id,
        timestamp: Time.current
      })

      # Start the import process asynchronously
      ImportJob.perform_later(username, job_tracker.id)

      @logger.info "Comment analysis pipeline initiated for #{username} with job_id: #{job_tracker.job_id}"

      # Return job information for tracking
      {
        job_id: job_tracker.job_id,
        status: job_tracker.status,
        message: "Analysis pipeline started for user: #{username}",
        progress_url: "/api/comments/progress/#{job_tracker.job_id}"
      }

    rescue ImportService::UserNotFoundError => e
      @logger.error "User not found in analysis pipeline: #{username} - #{e.message}"
      log_pipeline_event('user_not_found', {
        username: username,
        error: e.message,
        timestamp: Time.current
      })
      raise InvalidUsernameError, "User '#{username}' not found in external API"

    rescue => e
      @logger.error "Failed to start analysis pipeline for #{username}: #{e.message}"
      log_pipeline_event('pipeline_failed', {
        username: username,
        error: e.message,
        timestamp: Time.current
      })
      raise PipelineError, "Failed to start analysis pipeline: #{e.message}"
    end
  end

  # Get progress information for a job
  def get_analysis_progress(job_id)
    raise AnalysisError, "Job ID cannot be blank" if job_id.blank?

    begin
      job_tracker = JobTracker.find_by!(job_id: job_id)

      progress_info = {
        job_id: job_tracker.job_id,
        status: job_tracker.status,
        progress: job_tracker.progress,
        total: job_tracker.total,
        progress_percentage: job_tracker.progress_percentage,
        error_message: job_tracker.error_message,
        metadata: parse_job_metadata(job_tracker.metadata)
      }

      # Add estimated completion time if processing
      if job_tracker.processing? && job_tracker.progress > 0
        progress_info[:estimated_completion] = estimate_completion_time(job_tracker)
      end

      @logger.debug "Progress retrieved for job #{job_id}: #{job_tracker.progress}/#{job_tracker.total} (#{job_tracker.progress_percentage}%)"

      progress_info

    rescue ActiveRecord::RecordNotFound
      @logger.error "Job tracker not found for job_id: #{job_id}"
      raise AnalysisError, "Job not found: #{job_id}"
    rescue => e
      @logger.error "Failed to get progress for job #{job_id}: #{e.message}"
      raise AnalysisError, "Failed to retrieve job progress: #{e.message}"
    end
  end

  # Trigger manual recalculation of all metrics
  def recalculate_all_metrics
    @logger.info "Triggering manual recalculation of all metrics"

    begin
      log_pipeline_event('manual_recalculation_started', {
        trigger: 'manual',
        timestamp: Time.current
      })

      MetricsRecalculationJob.perform_later(nil, 'manual')

      @logger.info "Manual metrics recalculation job queued successfully"

      {
        status: 'queued',
        message: 'Metrics recalculation job has been queued',
        trigger: 'manual'
      }

    rescue => e
      @logger.error "Failed to queue manual metrics recalculation: #{e.message}"
      log_pipeline_event('manual_recalculation_failed', {
        error: e.message,
        timestamp: Time.current
      })
      raise PipelineError, "Failed to queue metrics recalculation: #{e.message}"
    end
  end

  # Get comprehensive analysis status for a user
  def get_user_analysis_status(username)
    raise InvalidUsernameError, "Username cannot be blank" if username.blank?

    begin
      # Find user by username (case-insensitive search)
      user = find_user_by_username(username)

      if user.nil?
        return {
          username: username,
          status: 'not_found',
          message: 'User has not been analyzed yet'
        }
      end

      # Get comment statistics
      comments = user.comments.includes(:post)
      comment_stats = calculate_comment_statistics(comments)

      # Get latest job tracker for this user
      latest_job = find_latest_job_for_user(username)

      # Get user metrics if available
      user_metrics = user.user_metrics

      status_info = {
        username: username,
        user_id: user.id,
        user_name: user.name,
        status: determine_user_status(comments, latest_job),
        comment_statistics: comment_stats,
        latest_job: latest_job ? format_job_info(latest_job) : nil,
        metrics_available: user_metrics.present?,
        last_analysis: user.updated_at,
        posts_count: user.posts.count
      }

      @logger.debug "User analysis status retrieved for #{username}: #{status_info[:status]}"

      status_info

    rescue => e
      @logger.error "Failed to get user analysis status for #{username}: #{e.message}"
      raise AnalysisError, "Failed to retrieve user status: #{e.message}"
    end
  end

  # Reprocess a specific user (useful for re-analysis with updated keywords)
  def reprocess_user(username)
    raise InvalidUsernameError, "Username cannot be blank" if username.blank?

    @logger.info "Starting reprocessing for username: #{username}"

    begin
      # Check if user exists in our system
      user = find_user_by_username(username)
      raise InvalidUsernameError, "User '#{username}' has not been analyzed before" unless user

      log_pipeline_event('reprocessing_started', {
        username: username,
        user_id: user.id,
        timestamp: Time.current
      })

      # Reset all comments to 'new' state for reprocessing
      reset_comments_for_reprocessing(user)

      # Start fresh analysis
      result = analyze_user_comments(username)

      @logger.info "Reprocessing initiated for #{username} with job_id: #{result[:job_id]}"

      result.merge({
        message: "Reprocessing started for user: #{username}",
        reprocessing: true
      })

    rescue InvalidUsernameError => e
      @logger.error "Invalid username for reprocessing: #{e.message}"
      raise
    rescue => e
      @logger.error "Failed to start reprocessing for #{username}: #{e.message}"
      log_pipeline_event('reprocessing_failed', {
        username: username,
        error: e.message,
        timestamp: Time.current
      })
      raise PipelineError, "Failed to start reprocessing: #{e.message}"
    end
  end

  private

  # Create a new job tracker for monitoring progress
  def create_job_tracker(username)
    job_id = SecureRandom.uuid

    JobTracker.create!(
      job_id: job_id,
      status: :pending,
      progress: 0,
      total: 100, # Will be updated by ImportJob with actual totals
      metadata: {
        username: username,
        pipeline_type: 'comment_analysis',
        started_at: Time.current
      }.to_json
    )
  end

  # Parse job metadata from JSON
  def parse_job_metadata(metadata_json)
    return {} if metadata_json.blank?

    JSON.parse(metadata_json)
  rescue JSON::ParserError => e
    @logger.warn "Failed to parse job metadata: #{e.message}"
    {}
  end

  # Estimate completion time based on current progress
  def estimate_completion_time(job_tracker)
    return nil unless job_tracker.metadata.present?

    begin
      metadata = parse_job_metadata(job_tracker.metadata)
      started_at = Time.parse(metadata['started_at']) if metadata['started_at']
      return nil unless started_at

      elapsed_time = Time.current - started_at
      progress_ratio = job_tracker.progress.to_f / job_tracker.total

      return nil if progress_ratio <= 0

      estimated_total_time = elapsed_time / progress_ratio
      estimated_remaining_time = estimated_total_time - elapsed_time

      {
        estimated_remaining_seconds: estimated_remaining_time.round,
        estimated_completion_at: Time.current + estimated_remaining_time
      }
    rescue => e
      @logger.warn "Failed to estimate completion time: #{e.message}"
      nil
    end
  end

  # Find user by username (case-insensitive)
  def find_user_by_username(username)
    # First try to find by exact match, then case-insensitive
    User.where(
      "users.name ILIKE ? OR users.email ILIKE ?",
      "%#{username}%",
      "%#{username}%"
    ).first
  end

  # Calculate comment statistics for a user
  def calculate_comment_statistics(comments)
    {
      total: comments.count,
      new: comments.count { |c| c.status == 'new' },
      processing: comments.count { |c| c.status == 'processing' },
      approved: comments.count { |c| c.status == 'approved' },
      rejected: comments.count { |c| c.status == 'rejected' },
      translated: comments.count { |c| c.translated_body.present? },
      with_keywords: comments.count { |c| (c.keyword_count || 0) > 0 }
    }
  end

  # Find the latest job tracker for a user
  def find_latest_job_for_user(username)
    JobTracker.where("metadata::text LIKE ?", "%#{username}%")
              .order(created_at: :desc)
              .first
  end

  # Determine overall status for a user
  def determine_user_status(comments, latest_job)
    return 'not_analyzed' if comments.empty?

    if latest_job&.processing?
      'processing'
    elsif latest_job&.failed?
      'failed'
    elsif comments.any? { |c| c.status == 'processing' }
      'processing'
    elsif comments.all? { |c| c.status.in?(['approved', 'rejected']) }
      'completed'
    else
      'partial'
    end
  end

  # Format job information for API response
  def format_job_info(job_tracker)
    {
      job_id: job_tracker.job_id,
      status: job_tracker.status,
      progress_percentage: job_tracker.progress_percentage,
      created_at: job_tracker.created_at,
      updated_at: job_tracker.updated_at,
      error_message: job_tracker.error_message
    }
  end

  # Reset comments for reprocessing
  def reset_comments_for_reprocessing(user)
    comments_to_reset = user.comments.where(status: ['approved', 'rejected'])

    @logger.info "Resetting #{comments_to_reset.count} comments for reprocessing (user: #{user.name})"

    comments_to_reset.update_all(
      status: 'new',
      translated_body: nil,
      keyword_count: nil,
      updated_at: Time.current
    )
  end

  # Structured logging for pipeline events
  def log_pipeline_event(event_type, data)
    log_entry = {
      event: event_type,
      service: 'CommentAnalysisService',
      timestamp: Time.current.iso8601,
      data: data
    }

    @logger.info "[PIPELINE_AUDIT] #{log_entry.to_json}"
  end
end
