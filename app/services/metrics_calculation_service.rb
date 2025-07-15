class MetricsCalculationService
    def self.calculate_for_user(user)
        user.calculate_metrics!
    end

    def self.calculate_group_metrics
        GroupMetrics.calculate_and_store!
    end

    def self.recalculate_all_users
        User.analyzed.find_each do |user| 
            
        user.comments.each do |comment|
            next unless comment.translated_body.present?
            comment.analyze_keywords!
        end
         
        calculate_for_user(user)
        end
         
        calculate_group_metrics
    end
end