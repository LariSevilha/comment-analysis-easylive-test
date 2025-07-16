require 'test_helper'

class CommentAnalysisServiceTest < ActiveSupport::TestCase
  def setup
    @service = CommentAnalysisService.new
    @username = 'testuser'

    # Clear any existing data
    JobTracker.destroy_all
    User.destroy_all

    # Setup test keywords without triggering callbacks
    Keyword.skip_callback(:save, :after, :trigger_recalculation)
    Keyword.skip_callback(:destroy, :after, :trigger_recalculation)

    Keyword.create!(word: 'great')
    Keyword.create!(word: 'excellent')
    Keyword.create!(word: 'amazing')
  end

  def teardown
    # Re-enable callbacks
    Keyword.set_callback(:save, :after, :trigger_recalculation)
    Keyword.set_callback(:destroy, :after, :trigger_recalculation)

    # Clean up after each test
    JobTracker.destroy_all
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all
    Keyword.destroy_all
  end

  test "analyze_user_comments creates job tracker and starts import job" do
    # Mock the ImportJob to avoid actual job execution
    ImportJob.expects(:perform_later).once.with(anything, anything)

    result = @service.analyze_user_comments(@username)

    assert_not_nil result[:job_id]
    assert_equal 'pending', result[:status]
    assert_includes result[:message], @username
    assert_includes result[:progress_url], result[:job_id]

    # Verify job tracker was created
    job_tracker = JobTracker.find_by(job_id: result[:job_id])
    assert_not_nil job_tracker
    assert_equal 'pending', job_tracker.status
    assert_equal 0, job_tracker.progress
    assert_equal 100, job_tracker.total
  end

  test "analyze_user_comments raises error for blank username" do
    error = assert_raises(CommentAnalysisService::InvalidUsernameError) do
      @service.analyze_user_comments('')
    end

    assert_includes error.message, 'cannot be blank'
  end

  test "analyze_user_comments handles import service errors" do
    # Mock ImportJob to raise an error
    ImportJob.expects(:perform_later).raises(ImportService::UserNotFoundError.new('User not found'))

    error = assert_raises(CommentAnalysisService::InvalidUsernameError) do
      @service.analyze_user_comments(@username)
    end

    assert_includes error.message, 'not found'
  end

  test "get_analysis_progress returns correct progress information" do
    # Create a job tracker
    job_tracker = JobTracker.create!(
      job_id: SecureRandom.uuid,
      status: :processing,
      progress: 50,
      total: 100,
      metadata: { username: @username, started_at: 1.hour.ago }.to_json
    )

    progress = @service.get_analysis_progress(job_tracker.job_id)

    assert_equal job_tracker.job_id, progress[:job_id]
    assert_equal 'processing', progress[:status]
    assert_equal 50, progress[:progress]
    assert_equal 100, progress[:total]
    assert_equal 50.0, progress[:progress_percentage]
    assert_not_nil progress[:estimated_completion]
  end

  test "get_analysis_progress raises error for non-existent job" do
    error = assert_raises(CommentAnalysisService::AnalysisError) do
      @service.get_analysis_progress('non-existent-job-id')
    end

    assert_includes error.message, 'Job not found'
  end

  test "recalculate_all_metrics queues metrics recalculation job" do
    # Stub the keyword callback to prevent unexpected job calls
    Keyword.any_instance.stubs(:trigger_recalculation)

    MetricsRecalculationJob.expects(:perform_later).once.with(nil, 'manual')

    result = @service.recalculate_all_metrics

    assert_equal 'queued', result[:status]
    assert_includes result[:message], 'queued'
    assert_equal 'manual', result[:trigger]
  end

  test "get_user_analysis_status returns not_found for non-existent user" do
    status = @service.get_user_analysis_status('nonexistent')

    assert_equal 'nonexistent', status[:username]
    assert_equal 'not_found', status[:status]
    assert_includes status[:message], 'not been analyzed'
  end

  test "get_user_analysis_status returns complete status for analyzed user" do
    # Create test user with posts and comments
    user = User.create!(name: 'Test User', username: "testuser", email: 'test@example.com', external_id: 1)
    post = Post.create!(user: user, title: 'Test Post', body: 'Test body', external_id: 1)

    # Create comments in different states
    Comment.create!(post: post, name: 'Comment 1', email: 'c1@example.com', body: 'Great comment', status: 'approved', keyword_count: 2, external_id: 1)
    Comment.create!(post: post, name: 'Comment 2', email: 'c2@example.com', body: 'Bad comment', status: 'rejected', keyword_count: 0, external_id: 2)

    status = @service.get_user_analysis_status('Test User')

    assert_equal 'Test User', status[:username]
    assert_equal user.id, status[:user_id]
    assert_equal 'completed', status[:status]
    assert_equal 2, status[:comment_statistics][:total]
    assert_equal 1, status[:comment_statistics][:approved]
    assert_equal 1, status[:comment_statistics][:rejected]
    assert_equal 1, status[:posts_count]
  end

  test "reprocess_user resets comments and starts new analysis" do
    # Create test user with processed comments
    user = User.create!(name: 'Test User', username: "testuser", email: 'test@example.com', external_id: 1)
    post = Post.create!(user: user, title: 'Test Post', body: 'Test body', external_id: 1)
    comment = Comment.create!(
      post: post,
      name: 'Comment 1',
      email: 'c1@example.com',
      body: 'Great comment',
      status: 'approved',
      keyword_count: 2,
      translated_body: 'Ótimo comentário',
      external_id: 1
    )

    # Mock ImportJob
    ImportJob.expects(:perform_later).once

    result = @service.reprocess_user('Test User')

    assert_not_nil result[:job_id]
    assert_includes result[:message], 'Reprocessing started'
    assert_equal true, result[:reprocessing]

    # Verify comment was reset
    comment.reload
    assert_equal 'new', comment.status
    assert_nil comment.translated_body
    assert_nil comment.keyword_count
  end

  test "reprocess_user raises error for non-existent user" do
    error = assert_raises(CommentAnalysisService::InvalidUsernameError) do
      @service.reprocess_user('nonexistent')
    end

    assert_includes error.message, 'not been analyzed before'
  end
end
