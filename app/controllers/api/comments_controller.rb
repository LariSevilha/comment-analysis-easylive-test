class Api::CommentsController < ApplicationController
  before_action :validate_analyze_params, only: [:analyze]
  before_action :find_job_tracker, only: [:progress]
  before_action :validate_username, only: [:metrics]

  # POST /api/comments/analyze
  def analyze
    begin
      # Start the comment analysis pipeline
      result = CommentAnalysisService.new.analyze_user_comments(params[:username])

      render json: {
        job_id: result[:job_id],
        status: 'started'
      }, status: :accepted
    rescue CommentAnalysisService::InvalidUsernameError => e
      render_error('VALIDATION_ERROR', 'Invalid username', e.message)
    rescue CommentAnalysisService::AnalysisError => e
      render_error('ANALYSIS_START_ERROR', 'Failed to start analysis', e.message)
    rescue => e
      render_error('ANALYSIS_START_ERROR', 'Failed to start analysis', e.message)
    end
  end

  # GET /api/comments/progress/:job_id
  def progress
    render json: JobProgressSerializer.serialize(@job_tracker)
  end

  # GET /api/comments/metrics/:username
  def metrics
    begin
      user = User.find_by(username: params[:username])

      unless user
        return render_error('USER_NOT_FOUND', 'User not found', "No user found with username: #{params[:username]}")
      end

      metrics_service = MetricsService.new
      user_metrics = metrics_service.calculate_user_metrics(user.id)
      group_metrics = metrics_service.calculate_group_metrics

      render json: {
        user_metrics: MetricsSerializer.serialize_user_metrics(user_metrics),
        group_metrics: MetricsSerializer.serialize_group_metrics(group_metrics),
        calculated_at: Time.current.iso8601
      }
    rescue => e
      render_error('METRICS_CALCULATION_ERROR', 'Failed to calculate metrics', e.message)
    end
  end

  private

  def validate_analyze_params
    unless params[:username].present?
      render_error('VALIDATION_ERROR', 'Username is required', 'The username parameter cannot be blank')
      return
    end

    if params[:username].length > 255
      render_error('VALIDATION_ERROR', 'Username too long', 'Username must be 255 characters or less')
      return
    end
  end

  def find_job_tracker
    @job_tracker = JobTracker.find_by(job_id: params[:job_id])

    unless @job_tracker
      render_error('JOB_NOT_FOUND', 'Job not found', "No job found with ID: #{params[:job_id]}")
      return
    end
  end

  def validate_username
    unless params[:username].present?
      render_error('VALIDATION_ERROR', 'Username is required', 'The username parameter cannot be blank')
      return
    end
  end

  def render_error(code, message, details = nil)
    error_response = ErrorSerializer.serialize(code, message, details)

    status_code = case code
                  when 'VALIDATION_ERROR' then :bad_request
                  when 'USER_NOT_FOUND', 'JOB_NOT_FOUND' then :not_found
                  else :internal_server_error
                  end

    render json: error_response, status: status_code
  end
end
