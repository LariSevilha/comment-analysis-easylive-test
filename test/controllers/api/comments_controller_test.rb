require 'test_helper'

class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Clean up any existing test data
    User.where(name: 'testuser').destroy_all
    JobTracker.where("metadata::text LIKE '%testuser%'").destroy_all

    @user = User.create!(
      name: 'Test User',
      username: 'testuser',
      email: 'test@example.com',
      external_id: "test_#{SecureRandom.hex(4)}"
    )

    @job_tracker = JobTracker.create!(
      job_id: SecureRandom.uuid,
      status: :processing,
      progress: 50,
      total: 100,
      metadata: { username: 'testuser' }.to_json
    )
  end

  test "should analyze comments with valid username" do
    # Mock the CommentAnalysisService
    CommentAnalysisService.any_instance.stubs(:analyze_user_comments).returns({
      job_id: @job_tracker.job_id,
      status: 'started'
    })

    post '/api/comments/analyze', params: { username: 'testuser' }

    assert_response :accepted
    json_response = JSON.parse(response.body)
    assert_equal @job_tracker.job_id, json_response['job_id']
    assert_equal 'started', json_response['status']
  end

  test "should return validation error for missing username" do
    post '/api/comments/analyze', params: {}

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal 'VALIDATION_ERROR', json_response['error']['code']
    assert_includes json_response['error']['message'], 'Username is required'
  end

  test "should return validation error for empty username" do
    post '/api/comments/analyze', params: { username: '' }

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal 'VALIDATION_ERROR', json_response['error']['code']
  end

  test "should get job progress" do
    get "/api/comments/progress/#{@job_tracker.job_id}"

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal @job_tracker.job_id, json_response['job_id']
    assert_equal 'processing', json_response['status']
    assert_equal 50, json_response['progress']
    assert_equal 100, json_response['total']
    assert_equal 50.0, json_response['progress_percentage']
  end

  test "should return not found for invalid job id" do
    get "/api/comments/progress/invalid-job-id"

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'JOB_NOT_FOUND', json_response['error']['code']
  end

  test "should get user metrics" do
    # Create some test data
    post = Post.create!(title: 'Test Post', body: 'Test body', external_id: "post_#{SecureRandom.hex(4)}", user: @user)
    Comment.create!(
      name: 'Test Comment',
      email: 'test@example.com',
      body: 'Test comment body',
      external_id: "comment_#{SecureRandom.hex(4)}",
      status: 'approved',
      keyword_count: 2,
      post: post
    )

    # Mock the MetricsService
    user_metrics = {
      user_id: @user.id,
      user_name: @user.name,
      total_comments: 1,
      approved_comments: 1,
      rejected_comments: 0,
      processing_comments: 0,
      avg_keyword_count: 2.0,
      median_keyword_count: 2.0,
      std_dev_keyword_count: 0.0,
      avg_approved_keyword_count: 2.0,
      median_approved_keyword_count: 2.0,
      std_dev_approved_keyword_count: 0.0,
      approval_rate: 100.0,
      rejection_rate: 0.0,
      calculated_at: Time.current
    }

    group_metrics = {
      total_users: 1,
      users_with_comments: 1,
      total_comments: 1,
      approved_comments: 1,
      rejected_comments: 0,
      processing_comments: 0,
      avg_keyword_count: 2.0,
      median_keyword_count: 2.0,
      std_dev_keyword_count: 0.0,
      avg_approved_keyword_count: 2.0,
      median_approved_keyword_count: 2.0,
      std_dev_approved_keyword_count: 0.0,
      avg_comments_per_user: 1.0,
      median_comments_per_user: 1.0,
      std_dev_comments_per_user: 0.0,
      approval_rate: 100.0,
      rejection_rate: 0.0,
      calculated_at: Time.current
    }

    MetricsService.any_instance.stubs(:calculate_user_metrics).returns(user_metrics)
    MetricsService.any_instance.stubs(:calculate_group_metrics).returns(group_metrics)

    get "/api/comments/metrics/#{@user.name}"

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['user_metrics']
    assert json_response['group_metrics']
    assert json_response['calculated_at']
  end

  test "should return not found for non-existent user metrics" do
    get "/api/comments/metrics/nonexistent"

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal 'USER_NOT_FOUND', json_response['error']['code']
  end
end
