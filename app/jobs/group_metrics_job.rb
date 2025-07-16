class GroupMetricsJob < ApplicationJob
    queue_as :metrics
    
    def perform
      @processing_job.update!(
        progress_info: "Calculating group metrics",
        total_items: 1,
        processed_items: 0
      )
      
      MetricsCalculationService.calculate_group_metrics
      
      @processing_job.update!(
        processed_items: 1,
        progress_info: "Group metrics calculated successfully"
      )
    end
  end
  