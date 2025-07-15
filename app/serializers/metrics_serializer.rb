class MetricsSerializer
    def initialize(metrics)
        @metrics = metrics
    end

    def as_json
        @metrics
    end
end