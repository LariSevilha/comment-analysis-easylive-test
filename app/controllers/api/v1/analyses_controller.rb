class Api::V1::AnalysesController < ApplicationController
  def create
    username = params[:username]
    job = UserAnalysisService.new(username).analyze!

    render json: {
      message: "Analysis started for user: #{username}",
      job_id: job.id,
      progress_url: api_v1_user_analysis_url(username, job.id)
    }, status: :accepted
  rescue ActionController::ParameterMissing
    render json: { error: 'Username is required' }, status: :bad_request
  rescue StandardError => e
    Rails.logger.error "Error starting analysis for #{username}: #{e.message}"
    render json: { error: "Failed to start analysis: #{e.message}" }, status: :unprocessable_entity
  end

  def show
    username = params[:username]
    job = AnalysisJob.where(job_type: 'user_analysis').where("metadata->>'username' = ?", username).find_by(id: params[:id])

    unless job
      render json: {
        username: username,
        status: 'not_found',
        message: 'No analysis found for this user'
      }, status: :not_found
      return
    end

    render json: {
      job_id: job.id,
      job_type: job.job_type,
      status: job.status,
      progress: {
        total_items: job.total_items || 0,
        processed_items: job.processed_items || 0,
        percentage: job.progress_percentage || 0.0
      },
      started_at: job.started_at,
      completed_at: job.completed_at,
      error_message: job.error_message,
      metadata: job.metadata
    }
  end
end