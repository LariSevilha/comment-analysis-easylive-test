require 'test_helper'

class MetricsRecalculationJobTest < ActiveJob::TestCase
  def setup
    @user = users(:one)
  end

  test "should enqueue metrics recalculation job" do
    assert_enqueued_with(job: MetricsRecalculationJob, args: [nil, 'manual']) do
      MetricsRecalculationJob.perform_later(nil, 'manual')
    end
  end

  test "should trigger keyword change recalculation" do
    assert_enqueued_with(job: MetricsRecalculationJob, args: [nil, 'keyword_change']) do
      MetricsRecalculationJob.trigger_keyword_change_recalculation
    end
  end

  test "should trigger user import completion recalculation" do
    assert_enqueued_with(job: MetricsRecalculationJob, args: [@user.id, 'user_import_completed']) do
      MetricsRecalculationJob.trigger_user_import_completion(@user.id)
    end
  end

  test "should trigger manual recalculation" do
    assert_enqueued_with(job: MetricsRecalculationJob, args: [nil, 'manual']) do
      MetricsRecalculationJob.trigger_manual_recalculation
    end
  end

  test "should trigger user specific recalculation" do
    assert_enqueued_with(job: MetricsRecalculationJob, args: [@user.id, 'user_specific']) do
      MetricsRecalculationJob.trigger_user_specific_recalculation(@user.id)
    end
  end

  test "should handle keyword change trigger" do
    # Mock the metrics service
    metrics_service = mock('metrics_service')
    MetricsService.expects(:new).returns(metrics_service)
    metrics_service.expects(:recalculate_all_metrics)

    perform_enqueued_jobs do
      MetricsRecalculationJob.perform_later(nil, 'keyword_change')
    end
  end

  test "should handle user import completed trigger" do
    # Mock the metrics service
    metrics_service = mock('metrics_service')
    MetricsService.expects(:new).returns(metrics_service)

    user_metrics = { total_comments: 5, approved_comments: 3 }
    group_metrics = { total_users: 10, total_comments: 50 }

    metrics_service.expects(:calculate_user_metrics).with(@user.id).returns(user_metrics)
    metrics_service.expects(:calculate_group_metrics).returns(group_metrics)

    perform_enqueued_jobs do
      MetricsRecalculationJob.perform_later(@user.id, 'user_import_completed')
    end
  end

  test "should handle manual trigger" do
    # Mock the metrics service
    metrics_service = mock('metrics_service')
    MetricsService.expects(:new).returns(metrics_service)
    metrics_service.expects(:recalculate_all_metrics)

    perform_enqueued_jobs do
      MetricsRecalculationJob.perform_later(nil, 'manual')
    end
  end

  test "should handle user specific trigger" do
    # Mock the metrics service
    metrics_service = mock('metrics_service')
    MetricsService.expects(:new).returns(metrics_service)

    user_metrics = { total_comments: 5, approved_comments: 3 }
    metrics_service.expects(:calculate_user_metrics).with(@user.id).returns(user_metrics)

    perform_enqueued_jobs do
      MetricsRecalculationJob.perform_later(@user.id, 'user_specific')
    end
  end

  test "should handle unknown trigger type" do
    # Mock the metrics service
    metrics_service = mock('metrics_service')
    MetricsService.expects(:new).returns(metrics_service)
    metrics_service.expects(:recalculate_all_metrics) # Should default to full recalculation

    perform_enqueued_jobs do
      MetricsRecalculationJob.perform_later(nil, 'unknown_trigger')
    end
  end
end
