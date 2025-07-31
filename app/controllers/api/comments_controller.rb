class Api::CommentsController < ApplicationController
  before_action :validate_analyze_params, only: [:analyze]
  before_action :find_job_tracker, only: [:progress]
  before_action :validate_username, only: [:metrics]
  before_action :validate_translate_params, only: [:translate]

  def index
    comments = Comment.all.select(:id, :name, :email, :body, :translated_body, :status, :keyword_count, :post_id)
    render json: { comments: comments.map { |c| CommentSerializer.serialize(c) } }
  end

  def analyze
    begin
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

  def translate
    begin
      comment_id = params[:comment_id]
      source_language = params[:source_language] || 'en'

      # Verify comment exists
      comment = Comment.find(comment_id)

      # Create job tracker with unique job_id
      job_tracker = JobTracker.create!(
        job_id: SecureRandom.uuid,
        status: 'pending',
        job_type: 'translation',
        total: 100,
        progress: 0
      )

      # Start translation job
      TranslationJob.perform_later(comment_id, job_tracker.id, 1, 1, source_language: source_language)

      render_success(
        data: {
          job_id: job_tracker.job_id,
          status: 'pending',
          comment_id: comment.id,
          source_language: source_language
        },
        status: :accepted,
        message: 'Translation started'
      )
    rescue ActiveRecord::RecordNotFound => e
      render_error('COMMENT_NOT_FOUND', 'Comment not found', "No comment found with ID: #{params[:comment_id]}", :not_found)
    rescue => e
      Rails.logger.error "Translation endpoint error: #{e.message}"
      render_error('TRANSLATION_ERROR', 'Failed to start translation', e.message)
    end
  end

  # POST /api/comments/reprocess
  def reprocess
    begin
      # Create job tracker for reprocessing
      job_tracker = JobTracker.create!(
        job_id: SecureRandom.uuid,
        status: 'pending',
        job_type: 'reprocessing',
        total: 100,
        progress: 0
      )

      # Start reprocessing job
      ReprocessCommentsJob.perform_later(job_tracker.id)

      render_success(
        data: {
          job_id: job_tracker.job_id,
          status: 'pending',
          message: 'Comment reprocessing started'
        },
        status: :accepted,
        message: 'Reprocessing started successfully'
      )
    rescue => e
      Rails.logger.error "Reprocessing endpoint error: #{e.message}"
      render_error('REPROCESSING_ERROR', 'Failed to start reprocessing', e.message)
    end
  end

  # GET /api/comments/:id/translation_status
  def translation_status
    begin
      comment = Comment.find(params[:id])
      
      render json: {
        comment_id: comment.id,
        status: comment.status,
        keyword_count: comment.keyword_count,
        has_translation: comment.translated_body.present?,
        original_text: comment.body,
        translated_text: comment.translated_body,
        classification_details: {
          approved: comment.approved?,
          meets_keyword_threshold: comment.keyword_count >= 2
        }
      }
    rescue ActiveRecord::RecordNotFound
      render_error('COMMENT_NOT_FOUND', 'Comment not found', "No comment found with ID: #{params[:id]}", :not_found)
    rescue => e
      Rails.logger.error "Translation status error: #{e.message}"
      render_error('STATUS_ERROR', 'Failed to get translation status', e.message)
    end
  end

  private

  def validate_translate_params
    unless params[:comment_id].present?
      render_error('VALIDATION_ERROR', 'Comment ID is required', 'The comment_id parameter cannot be blank', :bad_request)
      return
    end
    if params[:source_language].present? && !valid_language?(params[:source_language])
      render_error('VALIDATION_ERROR', 'Invalid source language', 'Supported languages: en, la, pt', :bad_request)
      return
    end
  end

  def valid_language?(lang)
    %w[en la pt].include?(lang)
  end

  def validate_analyze_params
    unless params[:username].present?
      render_error('VALIDATION_ERROR', 'Username is required', 'The username parameter cannot be blank', :bad_request)
      return
    end
    if params[:username].length > 255
      render_error('VALIDATION_ERROR', 'Username too long', 'Username must be 255 characters or less', :bad_request)
      return
    end
  end

  def find_job_tracker
    @job_tracker = JobTracker.find_by(job_id: params[:job_id])
    unless @job_tracker
      render_error('JOB_NOT_FOUND', 'Job not found', "No job found with ID: #{params[:job_id]}", :not_found)
      return
    end
  end

  def validate_username
    unless params[:username].present?
      render_error('VALIDATION_ERROR', 'Username is required', 'The username parameter cannot be blank', :bad_request)
      return
    end
  end

  def render_error(code, message, details = nil, status = :internal_server_error)
    error_response = ErrorSerializer.serialize(code, message, details)
    render json: error_response, status: status
  end

  def render_success(data:, status:, message: nil)
    response = { status: 'success', data: data }
    response[:message] = message if message
    render json: response, status: status
  end
end