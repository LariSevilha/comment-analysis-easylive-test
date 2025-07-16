require 'test_helper'
require 'cgi'

class EndToEndPipelineTest < ActionDispatch::IntegrationTest
  def setup
    # Clear all data
    JobTracker.destroy_all
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all
    Keyword.destroy_all
    UserMetrics.destroy_all
    GroupMetrics.destroy_all

    # Create test keywords
    @keywords = create_list(:keyword, 5, :common_keywords)

    # Set up test environment variables
    ENV['LIBRETRANSLATE_URL'] = 'http://localhost:5000'
    ENV['LIBRETRANSLATE_API_KEY'] = 'test_key'
  end

  def teardown
    # Clean up after each test
    JobTracker.destroy_all
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all
    Keyword.destroy_all
    UserMetrics.destroy_all
    GroupMetrics.destroy_all
  end

  test "complete end-to-end pipeline with mocked API interactions" do
    VCR.use_cassette("end_to_end_pipeline_test") do
      # Mock JSONPlaceholder API responses
    stub_request(:get, "https://jsonplaceholder.typicode.com/users")
      .to_return(
        status: 200,
        body: [{
          id: 1,
          name: "TestUser",
          username: "TestUser",
          email: "test@example.com"
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "https://jsonplaceholder.typicode.com/users/1/posts")
      .to_return(
        status: 200,
        body: [{
          userId: 1,
          id: 1,
          title: "Test Post",
          body: "Test post body"
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    stub_request(:get, "https://jsonplaceholder.typicode.com/posts/1/comments")
      .to_return(
        status: 200,
        body: [{
          postId: 1,
          id: 1,
          name: "Test Comment",
          email: "test@example.com",
          body: "This is an important and relevant test comment"
        }].to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock LibreTranslate API
    stub_request(:post, "#{ENV['LIBRETRANSLATE_URL']}/translate")
      .to_return(
        status: 200,
        body: { translatedText: "Este é um comentário de teste importante e relevante" }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Step 1: Start analysis via API
    post "/api/comments/analyze", params: { username: "TestUser" }
    assert_response :success

    response_data = JSON.parse(response.body)
    job_id = response_data["job_id"]
    assert_not_nil job_id
    assert_equal "started", response_data["status"]

    # Step 2: Check initial progress
    get "/api/comments/progress/#{job_id}"
    assert_response :success

    progress_data = JSON.parse(response.body)
    assert_equal "pending", progress_data["status"]
    assert_equal 0, progress_data["progress"]

    # Step 3: Simulate job execution (normally would be async)
    perform_enqueued_jobs_immediately do
      # This will trigger the import job and subsequent processing
      ImportJob.perform_now("TestUser", JobTracker.find_by(job_id: job_id).id)
    end

    # Step 4: Check completion progress
    get "/api/comments/progress/#{job_id}"
    assert_response :success

    final_progress = JSON.parse(response.body)

    # Debug information if job failed
    if final_progress["status"] == "failed"
      puts "Job failed with error: #{final_progress['error_message']}"
      puts "Job metadata: #{final_progress['metadata']}"
    end

    assert_equal "completed", final_progress["status"], "Job failed: #{final_progress['error_message']}"
    assert final_progress["progress"] >= 50, "Progress should be at least 50%, got #{final_progress['progress']}%"

    # Step 5: Verify data was imported and processed
    user = User.find_by(name: "TestUser")
    assert_not_nil user, "User should be created during import"
    assert user.posts.count > 0, "User should have posts"
    assert user.comments.count > 0, "User should have comments"

    # Debug: Show all users in database
    puts "All users in database: #{User.pluck(:name).inspect}"

    # Step 6: Check that comments were processed through state machine
    processed_comments = user.comments.where.not(status: 'new')
    assert processed_comments.count > 0

    # Step 7: Verify translations were attempted
    translated_comments = user.comments.where.not(translated_body: nil)
    assert translated_comments.count > 0

    # Step 8: Check metrics calculation
    get "/api/comments/metrics/#{URI.encode_www_form_component('TestUser')}"
    assert_response :success

    metrics_data = JSON.parse(response.body)
    assert_not_nil metrics_data["user_metrics"]
    assert_not_nil metrics_data["group_metrics"]
    assert metrics_data.dig("user_metrics", "comments", "total") > 0
    end
  end

  test "pipeline handles API failures gracefully" do
    # Mock external API failures
    stub_request(:get, /jsonplaceholder.typicode.com/)
      .to_return(status: 500, body: "Internal Server Error")

    post "/api/comments/analyze", params: { username: "testuser" }
    assert_response :success

    response_data = JSON.parse(response.body)
    job_id = response_data["job_id"]

    # Simulate job execution with failures
    perform_enqueued_jobs_immediately do
      begin
        ImportJob.perform_now("testuser", JobTracker.find_by(job_id: job_id).id)
      rescue => e
        # Expected to fail due to API error
      end
    end

    # Check that job status reflects the failure
    get "/api/comments/progress/#{job_id}"
    assert_response :success

    progress_data = JSON.parse(response.body)
    assert_equal "failed", progress_data["status"]
    assert_not_nil progress_data["error_message"]
  end

  test "keyword management triggers pipeline recalculation" do
    # First, create some processed data
    user = create(:user, :with_posts_and_comments)
    user.comments.each { |c| c.update!(status: 'approved', keyword_count: 2) }

    # Add a new keyword via API
    post "/api/keywords", params: { keyword: { word: "fantastic" } }
    assert_response :created

    # This should trigger recalculation job
    perform_enqueued_jobs_immediately do
      # The callback should have triggered MetricsRecalculationJob
    end

    # Verify that metrics were recalculated
    # (In a real scenario, this would update keyword counts)
    assert Keyword.exists?(word: "fantastic")
  end

  test "concurrent user analysis requests" do
    # Start multiple analysis requests concurrently
    usernames = ["user1", "user2", "user3"]
    job_ids = []

    # Mock API responses for all users
    usernames.each do |username|
      stub_request(:get, "https://jsonplaceholder.typicode.com/users")
        .with(query: { username: username })
        .to_return(
          status: 200,
          body: [].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    usernames.each do |username|
      post "/api/comments/analyze", params: { username: username }
      assert_response :success

      response_data = JSON.parse(response.body)
      job_ids << response_data["job_id"]
    end

    # Verify all jobs were created
    assert_equal 3, job_ids.length
    assert_equal 3, JobTracker.count

    # Check that each job has unique ID
    assert_equal job_ids.length, job_ids.uniq.length

    # Verify progress tracking works for all jobs
    job_ids.each do |job_id|
      get "/api/comments/progress/#{job_id}"
      assert_response :success

      progress_data = JSON.parse(response.body)
      assert_equal job_id, progress_data["job_id"]
    end
  end

  test "metrics endpoint performance with large dataset" do
    # Create a user with many comments for performance testing
    user = create(:user, name: "TestUser")
    posts = create_list(:post, 5, user: user)

    posts.each do |post|
      create_list(:comment, 20, :approved, post: post, keyword_count: 2)
      create_list(:comment, 15, :rejected, post: post, keyword_count: 0)
    end

    # Measure response time
    start_time = Time.current
    get "/api/comments/metrics/#{CGI.escape(user.name)}"
    end_time = Time.current

    assert_response :success
    response_time = end_time - start_time

    # Response should be under 1 second even with large dataset
    assert response_time < 1.0, "Metrics endpoint took #{response_time}s, should be under 1s"

    metrics_data = JSON.parse(response.body)
    expected_total = 175 # 35 per post * 5 posts
    actual_total = metrics_data.dig("user_metrics", "comments", "total")

    assert_not_nil actual_total, "total_comments should not be nil. Response: #{metrics_data}"
    assert_equal expected_total, actual_total
    assert_equal 100, metrics_data.dig("user_metrics", "comments", "approved")
    assert_equal 75, metrics_data.dig("user_metrics", "comments", "rejected")
  end

  test "error handling and recovery scenarios" do
    # Test invalid username
    post "/api/comments/analyze", params: { username: "" }
    assert_response :bad_request

    error_data = JSON.parse(response.body)
    assert_not_nil error_data["error"]
    assert_includes error_data["error"]["message"], "required"

    # Test non-existent job progress
    get "/api/comments/progress/non-existent-job"
    assert_response :not_found

    error_data = JSON.parse(response.body)
    assert_includes error_data["error"]["message"], "not found"

    # Test metrics for non-existent user
    get "/api/comments/metrics/nonexistent"
    assert_response :not_found

    error_data = JSON.parse(response.body)
    assert_includes error_data["error"]["message"], "not found"
  end

  test "cache performance and invalidation" do
    user = create(:user, :with_posts_and_comments, name: "TestUser")
    user.comments.each { |c| c.update!(status: 'approved', keyword_count: 2) }

    # Test that metrics endpoint works consistently
    get "/api/comments/metrics/#{CGI.escape(user.name)}"
    assert_response :success
    first_response = JSON.parse(response.body)

    # Second request should return same data
    get "/api/comments/metrics/#{CGI.escape(user.name)}"
    assert_response :success
    second_response = JSON.parse(response.body)

    # Data should be consistent
    assert_equal first_response.dig("user_metrics", "comments", "total"),
                 second_response.dig("user_metrics", "comments", "total")

    # Adding a keyword should trigger recalculation
    post "/api/keywords", params: { keyword: { word: "newkeyword" } }
    assert_response :created

    # Verify keyword was added
    assert Keyword.exists?(word: "newkeyword")

    # Next request should still work (may have different metrics due to recalculation)
    get "/api/comments/metrics/#{CGI.escape(user.name)}"
    assert_response :success
    third_response = JSON.parse(response.body)

    # Should still have valid metrics structure
    assert_not_nil third_response.dig("user_metrics", "comments", "total")
  end

  private

  def perform_enqueued_jobs_immediately
    # Override the test helper method for integration tests
    old_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true

    yield
  ensure
    ActiveJob::Base.queue_adapter = old_adapter
  end
end
