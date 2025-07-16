class ReprocessAllCommentsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting reprocessing of all comments due to keyword changes"
    
    job = AnalysisJob.create!(
      job_type: 'user_analysis',
      metadata: { username: @username },
      status: :pending,    
      total_items: 0,
      processed_items: 0,
      progress_percentage: 0.0
    )
    

    begin
      total_comments = Comment.count
      processed_count = 0
      
      # Reset counters
      User.update_all(
        approved_comments_count: 0,
        rejected_comments_count: 0,
        comments_count: 0
      )
      
      # Reprocessar todos os comentários
      Comment.find_each do |comment|
        # Reset status para reprocessar
        comment.update!(
          status: :pending,
          keyword_matches_count: 0,
          translated_body: nil,
          processed: nil
        )
        
        # Processar novamente
        comment.process_comment!
        processed_count += 1
        
        if processed_count % 10 == 0
          job.update_progress(processed_count, total_comments, 
                            "Reprocessed #{processed_count}/#{total_comments} comments")
        end
      end
      
      # Recalcular métricas de todos os usuários
      User.find_each do |user|
        RecalculateUserMetricsService.new(user).call
      end
      
      # Recalcular métricas do grupo
      RecalculateGroupMetricsService.new.call
      MetricsService.invalidate_cache
      
      job.mark_as_completed!
      Rails.logger.info "Reprocessing completed for #{total_comments} comments"
      
    rescue StandardError => e
      Rails.logger.error "Reprocessing failed: #{e.message}\n#{e.backtrace.join("\n")}"
      job.mark_as_failed!(e.message)
    end
  end
end