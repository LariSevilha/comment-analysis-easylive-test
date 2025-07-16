require 'test_helper'

class ApiEndpointsTest < ActionDispatch::IntegrationTest
  def setup
    # Clean up any existing test data
    User.where(name: 'integration_test_user').destroy_all
    JobTracker.where("metadata::text LIKE '%integration_test_user%'").destroy_all
  end

  test "API endpoints return proper JSON structure" do
    # Test validation error structure
    post '/api/comments/analyze', params: {}
    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert json_response['error']
    assert json_response['error']['code']
    assert json_response['error']['message']
    assert json_response['error']['timestamp']

    # Test job not found error structure
    get '/api/comments/progress/invalid-job-id'
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert json_response['error']
    assert_equal 'JOB_NOT_FOUND', json_response['error']['code']

    # Test user not found error structure
    get '/api/comments/metrics/nonexistent_user'
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert json_response['error']
    assert_equal 'USER_NOT_FOUND', json_response['error']['code']
  end

  test "successful responses have proper structure" do
    # Create test data
    user = User.create!(
      name: 'Integration Test User',
      username: 'integration_test_user',
      email: 'integration@test.com',
      external_id: "integration_#{SecureRandom.hex(4)}"
    )

    job_tracker = JobTracker.create!(
      job_id: SecureRandom.uuid,
      status: :completed,
      progress: 100,
      total: 100,
      metadata: { username: 'integration_test_user' }.to_json
    )

    # Test job progress response structure
    get "/api/comments/progress/#{job_tracker.job_id}"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['job_id']
    assert json_response['status']
    assert json_response['progress']
    assert json_response['total']
    assert json_response['progress_percentage']
    assert json_response['created_at']
    assert json_response['updated_at']

    # Mock metrics service for consistent test results
    user_metrics = {
      user_id: user.id,
      user_name: user.name,
      total_comments: 0,
      approved_comments: 0,
      rejected_comments: 0,
      processing_comments: 0,
      avg_keyword_count: 0.0,
      median_keyword_count: 0.0,
      std_dev_keyword_count: 0.0,
      avg_approved_keyword_count: 0.0,
      median_approved_keyword_count: 0.0,
      std_dev_approved_keyword_count: 0.0,
      approval_rate: 0.0,
      rejection_rate: 0.0,
      calculated_at: Time.current
    }

    group_metrics = {
      total_users: 1,
      users_with_comments: 0,
      total_comments: 0,
      approved_comments: 0,
      rejected_comments: 0,
      processing_comments: 0,
      avg_keyword_count: 0.0,
      median_keyword_count: 0.0,
      std_dev_keyword_count: 0.0,
      avg_approved_keyword_count: 0.0,
      median_approved_keyword_count: 0.0,
      std_dev_approved_keyword_count: 0.0,
      avg_comments_per_user: 0.0,
      median_comments_per_user: 0.0,
      std_dev_comments_per_user: 0.0,
      approval_rate: 0.0,
      rejection_rate: 0.0,
      calculated_at: Time.current
    }

    MetricsService.any_instance.stubs(:calculate_user_metrics).returns(user_metrics)
    MetricsService.any_instance.stubs(:calculate_group_metrics).returns(group_metrics)

    # Test metrics response structure
    get "/api/comments/metrics/#{user.name}"
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['user_metrics']
    assert json_response['group_metrics']
    assert json_response['calculated_at']

    # Verify user metrics structure
    user_metrics_response = json_response['user_metrics']
    assert user_metrics_response['user_id']
    assert user_metrics_response['user_name']
    assert user_metrics_response['comments']
    assert user_metrics_response['keyword_statistics']
    assert user_metrics_response['rates']

    # Verify group metrics structure
    group_metrics_response = json_response['group_metrics']
    assert group_metrics_response['users']
    assert group_metrics_response['comments']
    assert group_metrics_response['keyword_statistics']
    assert group_metrics_response['comments_per_user']
    assert group_metrics_response['rates']
  end
end
