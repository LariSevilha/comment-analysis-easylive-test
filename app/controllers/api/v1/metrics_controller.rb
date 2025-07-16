class Api::V1::MetricsController < ApplicationController
  def group
    begin
      metrics = MetricsService.group_metrics
      
      render json: {
        group_metrics: metrics,
        generated_at: Time.current,
        cache_status: Rails.cache.exist?('group_metrics') ? 'hit' : 'miss'
      }
    rescue StandardError => e
      Rails.logger.error "Failed to fetch group metrics: #{e.message}"
      render json: { 
        error: 'Failed to fetch metrics', 
        details: e.message 
      }, status: :internal_server_error
    end
  end

  def recalculate
    begin
      # Invalidar cache
      MetricsService.invalidate_cache
      
      # Recalcular métricas de todos os usuários
      User.processed.find_each do |user|
        RecalculateUserMetricsService.new(user).call
      end
      
      # Recalcular métricas do grupo
      RecalculateGroupMetricsService.new.call
      
      # Obter métricas atualizadas
      metrics = MetricsService.group_metrics
      
      render json: {
        message: 'Metrics recalculated successfully',
        group_metrics: metrics,
        recalculated_at: Time.current
      }
    rescue StandardError => e
      Rails.logger.error "Failed to recalculate metrics: #{e.message}"
      render json: { 
        error: 'Failed to recalculate metrics', 
        details: e.message 
      }, status: :internal_server_error
    end
  end
end