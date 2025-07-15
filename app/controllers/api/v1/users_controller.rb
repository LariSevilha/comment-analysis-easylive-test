class Api::V1::UsersController < ApplicationController
  def analyze
    username = params[:username] # Alterado de params.require(:username)

    job = UserAnalysisService.new(username).analyze!

    render json: {
      message: "Analysis started for user: #{username}",
      job_id: job.id,
      progress_url: api_v1_progress_url(username) # Usar username
    }, status: :accepted
  rescue ActionController::ParameterMissing
    render json: { error: 'Username is required' }, status: :bad_request
  end

  def show
    username = params[:username]

    if Rails.cache.exist?("user_analysis_#{username}")
      render json: Rails.cache.read("user_analysis_#{username}")
    else
      user = User.find_by!(username: username)
      group_metrics = GroupMetrics.latest

      response_data = {
        user: UserSerializer.new(user).as_json,
        metrics: user.analysis_metrics,
        group_metrics: group_metrics&.metrics_data || {},
        generated_at: Time.current
      }

      render json: response_data
    end
  end
end