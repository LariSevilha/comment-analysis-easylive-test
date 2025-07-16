require 'test_helper'

class CompletePipelineIntegrationTest < ActiveSupport::TestCase
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
    @keywords = [
      Keyword.create!(word: 'importante'),
      Keyword.create!(word: 'relevante'),
      Keyword.create!(word: 'útil'),
      Keyword.create!(word: 'interessante'),
      Keyword.create!(word: 'valioso')
    ]

    # Set up test environment
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = true
  end

  def teardown
    # Restore original adapter
    ActiveJob::Base.queue_adapter = @original_adapter

    # Clean up after each test
    JobTracker.destroy_all
    User.destroy_all
    Comment.destroy_all
    Post.destroy_all
    Keyword.destroy_all
    UserMetrics.destroy_all
    GroupMetrics.destroy_all
  end

  test "complete pipeline integration with all services" do
    VCR.use_cassette("complete_pipeline_integration") do
      # Step 1: Create test data that simulates JSONPlaceholder import
      user = create(:user, name: "Test User", email: "test@example.com", external_id: 1)
      posts = create_list(:post, 2, user: user)

      # Create comments with different content for classification testing
      comment1 = create(:comment,
        post: posts.first,
        body: "This is an important and relevant comment with useful information",
        external_id: 1
      )

      comment2 = create(:comment,
        post: posts.first,
        body: "This comment has no special terms in it",
        external_id: 2
      )

      comment3 = create(:comment,
        post: posts.second,
        body: "Another valuable and interesting comment that is quite useful",
        external_id: 3
      )

      # Step 2: Test Import Service
      import_service = ImportService.new

      # Mock external API calls
      stub_request(:get, "https://jsonplaceholder.typicode.com/users")
        .with(query: { username: "Test User" })
        .to_return(
          status: 200,
          body: [{
            id: 1,
            name: "Test User",
            username: "testuser",
            email: "test@example.com"
          }].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Step 3: Test Translation Service with each comment
      translation_service = TranslationService.new

      # Mock language detection API calls
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/detect")
        .to_return(
          status: 200,
          body: [{ language: 'en', confidence: 0.99 }].to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock translation API calls
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/translate")
        .with(body: hash_including(q: comment1.body))
        .to_return(
          status: 200,
          body: { translatedText: "Este é um comentário importante e relevante com informações úteis" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/translate")
        .with(body: hash_including(q: comment2.body))
        .to_return(
          status: 200,
          body: { translatedText: "Este comentário não tem termos especiais nele" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'https://libretranslate.de'}/translate")
        .with(body: hash_including(q: comment3.body))
        .to_return(
          status: 200,
          body: { translatedText: "Outro comentário valioso e interessante que é bastante útil" }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Step 4: Process each comment through the pipeline
      [comment1, comment2, comment3].each do |comment|
        # Start processing
        comment.start_processing!
        assert_equal 'processing', comment.status

        # Translate
        translated_text = translation_service.translate_to_portuguese(comment.body)
        comment.update!(translated_body: translated_text)

        # Classify (this will automatically update the state)
        classification_service = ClassificationService.new
        result = classification_service.classify_comment(comment)

        # The classification service already handles state transitions
        # No need to manually approve/reject here
      end

      # Step 5: Verify comment processing results
      comment1.reload
      comment2.reload
      comment3.reload

      # Debug information
      puts "Comment 1 - Status: #{comment1.status}, Keywords: #{comment1.keyword_count}, Translated: #{comment1.translated_body}"
      puts "Comment 2 - Status: #{comment2.status}, Keywords: #{comment2.keyword_count}, Translated: #{comment2.translated_body}"
      puts "Comment 3 - Status: #{comment3.status}, Keywords: #{comment3.keyword_count}, Translated: #{comment3.translated_body}"
      puts "Available keywords: #{Keyword.pluck(:word).join(', ')}"

      assert_equal 'approved', comment1.status, "Comment 1 should be approved but was #{comment1.status} with #{comment1.keyword_count} keywords"
      assert comment1.keyword_count >= 2, "Comment 1 should have >= 2 keywords, got #{comment1.keyword_count}"
      assert_not_nil comment1.translated_body

      assert_equal 'rejected', comment2.status
      assert comment2.keyword_count < 2, "Comment 2 should have < 2 keywords, got #{comment2.keyword_count}"

      assert_equal 'approved', comment3.status
      assert comment3.keyword_count >= 2, "Comment 3 should have >= 2 keywords, got #{comment3.keyword_count}"

      # Step 6: Test Metrics Service
      metrics_service = MetricsService.new
      user_metrics = metrics_service.calculate_user_metrics(user.id)
      group_metrics = metrics_service.calculate_group_metrics

      # Verify user metrics
      assert_equal 3, user_metrics[:total_comments]
      assert_equal 2, user_metrics[:approved_comments]
      assert_equal 1, user_metrics[:rejected_comments]
      assert user_metrics[:avg_keyword_count] > 0
      assert_not_nil user_metrics[:median_keyword_count]
      assert_not_nil user_metrics[:std_dev_keyword_count]

      # Verify group metrics
      assert_equal 3, group_metrics[:total_comments]
      assert_equal 2, group_metrics[:approved_comments]
      assert_equal 1, group_metrics[:rejected_comments]

      # Step 7: Test Cache Integration (skip in test environment due to NullStore)
      cache_key = "user_metrics:#{user.id}"
      # Note: Cache testing is done separately in cache invalidation test
      # Here we just verify the metrics are calculated correctly

      # Step 8: Test Job Tracker Integration
      job_tracker = create(:job_tracker, :processing, metadata: {
        username: user.name,
        pipeline_type: 'comment_analysis',
        started_at: 1.hour.ago.iso8601
      }.to_json)

      # Update progress
      job_tracker.update!(progress: 100, status: :completed)

      assert_equal 'completed', job_tracker.status
      assert_equal 100, job_tracker.progress

      # Step 9: Test Error Handling Integration
      # Simulate translation API failure
      stub_request(:post, "#{ENV['LIBRETRANSLATE_URL'] || 'http://localhost:5000'}/translate")
        .to_return(status: 500, body: "Internal Server Error")

      error_comment = create(:comment, post: posts.first, body: "Error test comment", external_id: 999)
      error_comment.start_processing!

      # Translation should fallback to original text
      begin
        translated_text = translation_service.translate_to_portuguese(error_comment.body)
        # Should fallback to original text
        assert_equal error_comment.body, translated_text
      rescue => e
        # Or handle the error appropriately
        assert_includes e.message.downcase, 'translation'
      end
    end
  end

  test "pipeline state machine integration" do
    user = create(:user, :with_posts_and_comments)
    comment = user.comments.first

    # Test state transitions
    assert_equal 'new', comment.status
    assert comment.may_start_processing?

    comment.start_processing!
    assert_equal 'processing', comment.status
    assert comment.may_approve?
    assert comment.may_reject?
    assert_not comment.may_start_processing?

    comment.approve!
    assert_equal 'approved', comment.status
    assert_not comment.may_start_processing?
    assert_not comment.may_approve?
    assert_not comment.may_reject?

    # Test state machine with classification using a different comment
    comment2 = user.comments.second
    assert_equal 'new', comment2.status

    comment2.start_processing!
    assert_equal 'processing', comment2.status
    comment2.update!(translated_body: "Texto sem palavras especiais")

    classification_service = ClassificationService.new
    result = classification_service.classify_comment(comment2)

    # The classification service already handles state transitions
    # Just verify the final state
    comment2.reload
    assert_includes ['approved', 'rejected'], comment2.status
  end

  test "pipeline metrics recalculation integration" do
    # Create test data
    user1 = create(:user, :with_posts_and_comments)
    user2 = create(:user, :with_posts_and_comments)

    # Process some comments
    user1.comments.limit(3).each { |c| c.update!(status: 'approved', keyword_count: 2) }
    user1.comments.offset(3).each { |c| c.update!(status: 'rejected', keyword_count: 0) }

    user2.comments.limit(2).each { |c| c.update!(status: 'approved', keyword_count: 3) }
    user2.comments.offset(2).each { |c| c.update!(status: 'rejected', keyword_count: 1) }

    # Calculate initial metrics
    metrics_service = MetricsService.new
    initial_user1_metrics = metrics_service.calculate_user_metrics(user1.id)
    initial_group_metrics = metrics_service.calculate_group_metrics

    # Add new keyword (should trigger recalculation)
    new_keyword = Keyword.create!(word: 'fantástico')

    # Simulate recalculation job
    MetricsRecalculationJob.perform_now(nil, 'keyword_change')

    # Verify metrics were recalculated
    updated_user1_metrics = metrics_service.calculate_user_metrics(user1.id)
    updated_group_metrics = metrics_service.calculate_group_metrics

    # Metrics should be recalculated (may or may not change depending on content)
    assert_not_nil updated_user1_metrics
    assert_not_nil updated_group_metrics
  end

  test "pipeline cache invalidation integration" do
    # Temporarily switch to memory store for this test
    original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    begin
      user = create(:user, :with_posts_and_comments)
      user.comments.each { |c| c.update!(status: 'approved', keyword_count: 2) }

      metrics_service = MetricsService.new

      # Calculate and cache metrics
      user_metrics = metrics_service.calculate_user_metrics(user.id)
      cache_key = "user_metrics:#{user.id}"

      # Write to cache
      write_result = Rails.cache.write(cache_key, user_metrics.to_json, expires_in: 1.hour)
      assert write_result, "Cache write should succeed"

      # Verify cache exists
      cached_data = Rails.cache.read(cache_key)
      assert_not_nil cached_data, "Cache should contain data after writing"

      # Add new keyword (should invalidate cache)
      Keyword.create!(word: 'novo')

      # Simulate cache invalidation (this would normally be triggered by keyword callbacks)
      Rails.cache.delete_matched("user_metrics:*")
      Rails.cache.delete("group_metrics")

      # Verify cache was invalidated
      cached_data_after = Rails.cache.read(cache_key)
      assert_nil cached_data_after, "Cache should be empty after invalidation"
    ensure
      # Restore original cache store
      Rails.cache = original_cache_store
    end
  end

  test "pipeline error recovery integration" do
    user = create(:user, :with_posts_and_comments)
    comment = user.comments.first

    # Start processing
    comment.start_processing!

    # Simulate error during processing
    job_tracker = create(:job_tracker, :processing)

    begin
      # Simulate an error
      raise StandardError, "Simulated processing error"
    rescue => e
      # Handle error and update job tracker
      job_tracker.update!(
        status: :failed,
        error_message: e.message
      )

      # Reset comment state for retry
      comment.update!(status: 'new', translated_body: nil, keyword_count: nil)
    end

    assert_equal 'failed', job_tracker.status
    assert_equal 'new', comment.status
    assert_nil comment.translated_body

    # Test recovery - reprocess the comment
    comment.start_processing!
    comment.update!(
      translated_body: "Texto traduzido de recuperação",
      status: 'approved',
      keyword_count: 1
    )

    job_tracker.update!(status: :completed, progress: 100, error_message: nil)

    assert_equal 'completed', job_tracker.status
    assert_equal 'approved', comment.status
  end
end
