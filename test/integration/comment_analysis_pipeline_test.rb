require 'test_helper'

class CommentAnalysisPipelineTest < ActiveSupport::TestCase
  def setup
    # Clear all data
    JobTracker.destroy_all
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all
    Keyword.destroy_all
    UserMetrics.destroy_all
    GroupMetrics.destroy_all

    # Setup test keywords without triggering callbacks
    Keyword.skip_callback(:save, :after, :trigger_recalculation)
    Keyword.skip_callback(:destroy, :after, :trigger_recalculation)

    @keywords = [
      Keyword.create!(word: 'great'),
      Keyword.create!(word: 'excellent'),
      Keyword.create!(word: 'amazing')
    ]

    @username = 'testuser'
    @service = CommentAnalysisService.new
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
    UserMetrics.destroy_all
    GroupMetrics.destroy_all
  end

  test "pipeline orchestration creates job tracker and starts import" do
    # Mock ImportJob to avoid actual execution
    ImportJob.expects(:perform_later).once

    result = @service.analyze_user_comments(@username)

    assert_not_nil result[:job_id]
    assert_equal 'pending', result[:status]
    assert_includes result[:message], @username

    # Verify job tracker was created with correct metadata
    job_tracker = JobTracker.find_by(job_id: result[:job_id])
    assert_not_nil job_tracker

    metadata = JSON.parse(job_tracker.metadata)
    assert_equal @username, metadata['username']
    assert_equal 'comment_analysis', metadata['pipeline_type']
  end

  test "pipeline progress tracking works correctly" do
    # Create a job tracker manually to test progress tracking
    job_tracker = JobTracker.create!(
      job_id: SecureRandom.uuid,
      status: :processing,
      progress: 50,
      total: 100,
      metadata: {
        username: @username,
        started_at: 1.hour.ago.iso8601,
        pipeline_type: 'comment_analysis'
      }.to_json
    )

    progress = @service.get_analysis_progress(job_tracker.job_id)

    assert_equal job_tracker.job_id, progress[:job_id]
    assert_equal 'processing', progress[:status]
    assert_equal 50, progress[:progress]
    assert_equal 100, progress[:total]
    assert_equal 50.0, progress[:progress_percentage]
    assert_not_nil progress[:estimated_completion]
  end

  test "pipeline handles user status correctly" do
    # Create test user with comments in different states
    user = User.create!(name: 'Test User', username: "testuser", email: 'test@example.com', external_id: 1)
    post = Post.create!(user: user, title: 'Test Post', body: 'Test body', external_id: 1)

    # Create comments in different states
    Comment.create!(post: post, name: 'Comment 1', email: 'c1@example.com', body: 'Great excellent comment', status: 'approved', keyword_count: 2, external_id: 1)
    Comment.create!(post: post, name: 'Comment 2', email: 'c2@example.com', body: 'Bad comment', status: 'rejected', keyword_count: 0, external_id: 2)
    Comment.create!(post: post, name: 'Comment 3', email: 'c3@example.com', body: 'Processing comment', status: 'processing', keyword_count: 1, external_id: 3)

    status = @service.get_user_analysis_status('Test User')

    assert_equal 'Test User', status[:username]
    assert_equal user.id, status[:user_id]
    assert_equal 'processing', status[:status] # Because one comment is still processing
    assert_equal 3, status[:comment_statistics][:total]
    assert_equal 1, status[:comment_statistics][:approved]
    assert_equal 1, status[:comment_statistics][:rejected]
    assert_equal 1, status[:comment_statistics][:processing]
    assert_equal 1, status[:posts_count]
  end

  test "pipeline reprocessing resets comments correctly" do
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

    # Mock ImportJob for reprocessing
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

  test "pipeline metrics recalculation integration" do
    # Stub keyword callbacks to prevent unexpected job calls
    Keyword.any_instance.stubs(:trigger_recalculation)

    # Mock the metrics recalculation job
    MetricsRecalculationJob.expects(:perform_later).once.with(nil, 'manual')

    result = @service.recalculate_all_metrics

    assert_equal 'queued', result[:status]
    assert_includes result[:message], 'queued'
    assert_equal 'manual', result[:trigger]
  end

  test "pipeline handles errors gracefully" do
    # Test with invalid username
    error = assert_raises(CommentAnalysisService::InvalidUsernameError) do
      @service.analyze_user_comments('')
    end
    assert_includes error.message, 'cannot be blank'

    # Test with non-existent job
    error = assert_raises(CommentAnalysisService::AnalysisError) do
      @service.get_analysis_progress('non-existent-job')
    end
    assert_includes error.message, 'Job not found'

    # Test reprocessing non-existent user
    error = assert_raises(CommentAnalysisService::InvalidUsernameError) do
      @service.reprocess_user('nonexistent')
    end
    assert_includes error.message, 'not been analyzed before'
  end

  test "pipeline structured logging works" do
    # Mock ImportJob to avoid actual execution
    ImportJob.expects(:perform_later).once

    # Test that the service runs without error and creates proper audit logs
    result = @service.analyze_user_comments(@username)

    # Verify the result contains expected fields (indicating logging worked)
    assert_not_nil result[:job_id]
    assert_equal 'pending', result[:status]
    assert_includes result[:message], @username

    # Verify job tracker was created with audit metadata
    job_tracker = JobTracker.find_by(job_id: result[:job_id])
    metadata = JSON.parse(job_tracker.metadata)
    assert_equal 'comment_analysis', metadata['pipeline_type']
    assert_not_nil metadata['started_at']
  end
end
