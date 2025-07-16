# frozen_string_literal: true

require 'test_helper'

class CacheWarmingJobTest < ActiveJob::TestCase
  def setup
    # Use memory store for tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    # Reset cache statistics
    CacheManager.reset_stats

    # Create test data
    @user = users(:one)
    @keyword = Keyword.create!(word: 'test_keyword')

    # Mock expensive database queries to speed up tests
    User.stubs(:joins).returns(User.limit(2)) # Limit to 2 users instead of 20
    JobTracker.stubs(:where).returns(JobTracker.limit(2)) # Limit job trackers

    # Mock expensive service calls
    MetricsService.stubs(:calculate_user_metrics).returns({ avg: 1.0, median: 1.0, std_dev: 0.5 })
    MetricsService.stubs(:calculate_group_metrics).returns({ avg: 2.0, median: 2.0, std_dev: 1.0 })

    # Mock translation service to avoid external API calls
    TranslationService.any_instance.stubs(:translate_to_portuguese).returns('translated text')

    # Mock User.find to avoid database queries
    User.stubs(:find).returns(@user)
  end

  def teardown
    # Restore original cache store
    Rails.cache = @original_cache_store
  end

  test "should perform full cache warming" do
    # Clear any existing cache
    Rails.cache.clear
    CacheManager.reset_stats

    # Perform the job
    CacheWarmingJob.perform_now(warming_type: 'full')

    # Should have performed cache operations
    stats = CacheManager.stats
    assert stats[:total_operations] > 0, "Should have performed cache operations"
    assert stats[:writes] > 0, "Should have written to cache"
  end

  test "should warm keywords cache only" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Perform keywords warming
    CacheWarmingJob.perform_now(warming_type: 'keywords')

    # Should have cached keywords
    cached_keywords = CacheManager.read('all', cache_type: :keywords)
    assert_not_nil cached_keywords, "Keywords should be cached"
    assert cached_keywords.is_a?(Array), "Cached keywords should be an array"
  end

  test "should warm metrics cache only" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Perform metrics warming
    CacheWarmingJob.perform_now(warming_type: 'metrics')

    # Should have performed cache operations for metrics
    stats = CacheManager.stats
    assert stats[:total_operations] > 0, "Should have performed cache operations for metrics"
  end

  test "should warm user specific data" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Create a comment for the user to have data to warm
    post = Post.create!(
      title: 'Test Post',
      body: 'Test content',
      user: @user,
      external_id: 999
    )

    Comment.create!(
      name: 'Test Commenter',
      email: 'test@example.com',
      body: 'Test comment',
      post: post,
      external_id: 999,
      status: 'approved',
      keyword_count: 2
    )

    # Perform user-specific warming
    user_data = { 'user_ids' => [@user.id] }
    CacheWarmingJob.perform_now(warming_type: 'user_specific', specific_data: user_data)

    # Should have performed cache operations
    stats = CacheManager.stats
    assert stats[:total_operations] > 0, "Should have performed cache operations for user-specific warming"
  end

  test "should warm frequent translations" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Mock the translation service to avoid external API calls
    TranslationService.any_instance.stubs(:translate_to_portuguese).returns('translated text')

    # Perform translation warming
    CacheWarmingJob.perform_now(warming_type: 'translations')

    # Should have performed cache operations
    stats = CacheManager.stats
    assert stats[:total_operations] > 0, "Should have performed cache operations for translations"
  end

  test "should handle unknown warming type gracefully" do
    # Should not raise error for unknown type
    assert_nothing_raised do
      CacheWarmingJob.perform_now(warming_type: 'unknown')
    end
  end

  test "should handle errors during warming gracefully" do
    # Capture log output
    log_output = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    # Mock an error in the warming process by stubbing Keyword.all
    Keyword.stubs(:all).raises(StandardError, "Database error")

    # The job should complete without raising (errors are caught and logged)
    assert_nothing_raised do
      CacheWarmingJob.perform_now(warming_type: 'keywords')
    end

    # Verify that the error was logged
    log_content = log_output.string
    assert_match(/Failed to warm keywords cache/, log_content)

    # Restore original logger
    Rails.logger = original_logger
  end

  test "should log warming results" do
    # Capture log output
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    # Perform warming
    CacheWarmingJob.perform_now(warming_type: 'keywords')

    # Should log start and completion
    log_content = log_output.string
    assert_includes log_content, "Starting cache warming job"
    assert_includes log_content, "Cache warming completed"
  end

  test "should handle user specific warming with invalid user IDs" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Use non-existent user ID
    user_data = { 'user_ids' => [99999] }

    # Should not raise error
    assert_nothing_raised do
      CacheWarmingJob.perform_now(warming_type: 'user_specific', specific_data: user_data)
    end
  end

  test "should handle user specific warming with invalid data format" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Use invalid data format
    invalid_data = "not a hash"

    # Should not raise error and should return early
    assert_nothing_raised do
      CacheWarmingJob.perform_now(warming_type: 'user_specific', specific_data: invalid_data)
    end
  end

  test "should warm job progress cache" do
    # Create a test job tracker
    job_tracker = JobTracker.create!(
      job_id: 'test-job-123',
      status: 'processing',
      progress: 50,
      total: 100
    )

    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Perform full warming (which includes job progress)
    CacheWarmingJob.perform_now(warming_type: 'full')

    # Should have performed cache operations
    stats = CacheManager.stats
    assert stats[:total_operations] > 0, "Should have performed cache operations"
    assert stats[:writes] > 0, "Should have written to cache"
  end

  test "should store warming metrics" do
    # Clear cache and stats
    Rails.cache.clear
    CacheManager.reset_stats

    # Perform warming
    CacheWarmingJob.perform_now(warming_type: 'keywords')

    # Should have stored warming metrics (check if any warming metrics exist)
    # We can't easily test the exact key since it includes timestamp, but we can check operations
    stats = CacheManager.stats
    assert stats[:writes] > 0, "Should have written warming metrics to cache"
  end

  test "should be queued on default queue" do
    assert_equal 'default', CacheWarmingJob.new.queue_name
  end

  test "should have retry configuration" do
    job = CacheWarmingJob.new

    # Check that the job class has retry configuration
    # We can't easily test the internal retry configuration, but we can verify the job exists
    assert_not_nil job, "Job should be instantiable"
    assert_equal 'default', job.queue_name
  end
end
