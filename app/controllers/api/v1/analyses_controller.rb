class Api::V1::AnalysesController < ApplicationController
  def create 
    username = params[:username] || params[:analysis]&.[](:username)
    
    if username.blank?
      Rails.logger.warn "Username missing in request: #{params.inspect}"
      render json: { error: 'Username is required' }, status: :bad_request
      return
    end

    Rails.logger.info "Starting analysis for username: #{username}"
    
    begin
      # Check for existing job
      existing_job = AnalysisJob.where(
        job_type: 'user_analysis',
        status: %w[pending running]
      ).where("metadata->>'username' = ?", username).first

      if existing_job
        Rails.logger.info "Existing job found for #{username}: job_id=#{existing_job.id}, status=#{existing_job.status}"
        render json: {
          job_id: existing_job.id,
          status: existing_job.status,
          message: 'Analysis already in progress for this user'
        }, status: :accepted
        return
      end

      # Create new analysis job
      job = UserAnalysisService.new(username).analyze!
      
      Rails.logger.info "Analysis job created for #{username}: job_id=#{job.id}"
      render json: {
        job_id: job.id,
        status: job.status,
        username: username,
        message: 'Analysis started successfully'
      }, status: :accepted
      
    rescue StandardError => e
      Rails.logger.error "Analysis creation failed for #{username}: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { 
        error: 'Failed to start analysis', 
        details: e.message 
      }, status: :internal_server_error
    end
  end

  def show
    job = AnalysisJob.find(params[:id])
    
    case job.status
    when 'completed'
      username = job.metadata['username']
      user = User.find_by(username: username)
      
      if user
        render json: build_analysis_response(user, job)
      else
        render json: { error: 'User not found' }, status: :not_found
      end
    when 'failed'
      render json: {
        job_id: job.id,
        status: job.status,
        error: job.error_message,
        started_at: job.started_at,
        completed_at: job.completed_at
      }, status: :unprocessable_entity
    else
      render json: {
        job_id: job.id,
        status: job.status,
        progress: job.progress_percentage,
        current_step: job.metadata['current_step'],
        processed_items: job.processed_items,
        total_items: job.total_items,
        started_at: job.started_at
      }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Analysis job not found' }, status: :not_found
  end

  private

  def build_analysis_response(user, job)
    {
      job_id: job.id,
      status: job.status,
      user_analysis: {
        username: user.username,
        user_id: user.id,
        total_posts: user.posts.count,
        total_comments: user.comments.count,
        approved_comments: user.approved_comments_count,
        rejected_comments: user.rejected_comments_count,
        approval_rate: user.approval_rate,
        user_metrics: user.analysis_metrics || {}
      },
      group_metrics: MetricsService.group_metrics,
      processing_info: {
        started_at: job.started_at,
        completed_at: job.completed_at,
        processed_items: job.processed_items,
        total_items: job.total_items
      }
    }
  end
end