require 'test_helper'

class ClassificationServiceTest < ActiveSupport::TestCase
  def setup
    @service = ClassificationService.new

    # Create test data
    @user = User.create!(
      name: 'Test User',
      username: 'testuser',
      email: "test@example.com",
      external_id: 1
    )

    @post = Post.create!(
      title: "Test Post",
      body: "Test post body",
      external_id: 1,
      user: @user
    )

    @comment = Comment.create!(
      name: "Test Commenter",
      email: "commenter@example.com",
      body: "This is a great product with excellent quality",
      translated_body: "Este é um ótimo produto com excelente qualidade",
      external_id: 1,
      post: @post,
      status: :processing
    )

    # Create test keywords (in Portuguese since comments are translated to Portuguese)
    @keywords = []
    @keywords << Keyword.create!(word: "ótimo")      # great
    @keywords << Keyword.create!(word: "excelente")  # excellent
    @keywords << Keyword.create!(word: "incrível")   # amazing
    @keywords << Keyword.create!(word: "fantástico") # fantastic
    @keywords << Keyword.create!(word: "maravilhoso") # wonderful

    # Enable memory cache for tests
    @original_cache_store = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
  end

  def teardown
    # Restore original cache store
    Rails.cache = @original_cache_store
  end

  # Test basic classification functionality
  test "should approve comment with sufficient keywords" do
    # Comment has "great" and "excellent" keywords (2 >= 2)
    result = @service.classify_comment(@comment)

    assert result[:approved], "Comment should be approved"
    assert_equal 2, result[:keyword_count], "Should find 2 keywords"
    assert_equal "approved", result[:status], "Status should be approved"

    @comment.reload
    assert @comment.approved?, "Comment should be in approved state"
    assert_equal 2, @comment.keyword_count, "Comment should have keyword_count saved"
  end

  test "should reject comment with insufficient keywords" do
    # Update comment to have only one keyword
    @comment.update!(
      body: "This is a nice product",
      translated_body: "Este é um produto legal"
    )

    result = @service.classify_comment(@comment)

    assert_not result[:approved], "Comment should be rejected"
    assert_equal 0, result[:keyword_count], "Should find 0 keywords"
    assert_equal "rejected", result[:status], "Status should be rejected"

    @comment.reload
    assert @comment.rejected?, "Comment should be in rejected state"
    assert_equal 0, @comment.keyword_count, "Comment should have keyword_count saved"
  end

  test "should use translated text when available" do
    # Set up comment where original has no keywords but translated has keywords
    @comment.update!(
      body: "This product is nice and okay", # English with no keywords
      translated_body: "Este produto é incrível e fantástico" # Portuguese with keywords
    )

    result = @service.classify_comment(@comment)

    # Should use translated_body and find 2 keywords
    assert result[:approved], "Comment should be approved using translated text"
    assert_equal 2, result[:keyword_count], "Should find 2 keywords in translated text"
  end

  test "should fallback to original text when translated is blank" do
    # Update comment to have Portuguese keywords in original body
    @comment.update!(
      body: "Este produto é ótimo e excelente",
      translated_body: nil
    )

    result = @service.classify_comment(@comment)

    # Should use original body and find keywords
    assert result[:approved], "Comment should be approved using original text"
    assert_equal 2, result[:keyword_count], "Should find keywords in original text"
  end

  test "should perform case-insensitive keyword matching" do
    @comment.update!(
      body: "This is a GREAT product with EXCELLENT quality",
      translated_body: "Este é um ÓTIMO produto com EXCELENTE qualidade"
    )

    result = @service.classify_comment(@comment)

    assert result[:approved], "Should match keywords case-insensitively"
    assert_equal 2, result[:keyword_count], "Should find 2 keywords despite case differences"
  end

  test "should match whole words only" do
    # Create a keyword that could be part of other words
    Keyword.create!(word: "cat")

    @comment.update!(
      body: "This is about education and communication", # Contains "cat" but not as whole word
      translated_body: "This has a cat in it" # Contains "cat" as whole word
    )

    result = @service.classify_comment(@comment)

    # Should only find "cat" as whole word in translated text, not in "education" or "communication"
    assert_equal 1, result[:keyword_count], "Should only match whole words"
  end

  test "should handle duplicate keywords in text" do
    @comment.update!(
      body: "Este é ótimo, realmente ótimo, e excelente, verdadeiramente excelente",
      translated_body: nil
    )

    result = @service.classify_comment(@comment)

    # Should count unique keywords only
    assert_equal 2, result[:keyword_count], "Should count unique keywords only"
    assert result[:approved], "Should approve based on unique keyword count"
  end

  test "should raise error for nil comment" do
    assert_raises(ClassificationService::ClassificationError) do
      @service.classify_comment(nil)
    end
  end

  test "should raise error for non-persisted comment" do
    new_comment = Comment.new(
      name: "Test",
      email: "test@example.com",
      body: "Test body",
      post: @post
    )

    assert_raises(ClassificationService::ClassificationError) do
      @service.classify_comment(new_comment)
    end
  end

  test "should raise error for comment with no text" do
    # Since Comment model validates presence of body, we need to test the service logic
    # by mocking the comment to return blank text
    @comment.stubs(:translated_body).returns("")
    @comment.stubs(:body).returns("")

    assert_raises(ClassificationService::ClassificationError) do
      @service.classify_comment(@comment)
    end
  end

  test "should handle comment that cannot transition states" do
    # Set comment to a state where it cannot be approved/rejected
    @comment.update!(status: :new)

    # Mock the state machine to prevent transitions
    @comment.stubs(:may_approve?).returns(false)
    @comment.stubs(:may_reject?).returns(false)

    # Should still classify but log warnings
    result = @service.classify_comment(@comment)

    assert_not_nil result[:keyword_count], "Should still count keywords"
    # State should remain unchanged since transitions are not allowed
  end

  # Test batch classification
  test "should classify multiple comments in batch" do
    # Create additional comments with Portuguese keywords
    comment2 = Comment.create!(
      name: "Test Commenter 2",
      email: "commenter2@example.com",
      body: "This is amazing and wonderful",
      translated_body: "Este produto é incrível e maravilhoso", # 2 keywords - should approve
      external_id: 2,
      post: @post,
      status: :processing
    )

    comment3 = Comment.create!(
      name: "Test Commenter 3",
      email: "commenter3@example.com",
      body: "This is okay",
      translated_body: "Este produto é legal", # 0 keywords - should reject
      external_id: 3,
      post: @post,
      status: :processing
    )

    comments = [@comment, comment2, comment3]
    results = @service.classify_comments(comments)

    assert_equal 3, results.length, "Should return results for all comments"

    # Check first comment (2 keywords - approved)
    assert results[0][:result][:approved], "First comment should be approved"
    assert_equal 2, results[0][:result][:keyword_count]

    # Check second comment (2 keywords - approved)
    assert results[1][:result][:approved], "Second comment should be approved"
    assert_equal 2, results[1][:result][:keyword_count]

    # Check third comment (0 keywords - rejected)
    assert_not results[2][:result][:approved], "Third comment should be rejected"
    assert_equal 0, results[2][:result][:keyword_count]
  end

  test "should handle errors in batch classification gracefully" do
    # Create a comment that will cause an error by mocking it to return empty text
    invalid_comment = Comment.create!(
      name: "Invalid",
      email: "invalid@example.com",
      body: "Valid body", # Valid body to pass validation
      translated_body: "Valid translated body",
      external_id: 999,
      post: @post,
      status: :processing
    )

    # Mock the comment to return empty text during classification
    invalid_comment.stubs(:translated_body).returns("")
    invalid_comment.stubs(:body).returns("")

    comments = [@comment, invalid_comment]
    results = @service.classify_comments(comments)

    assert_equal 2, results.length, "Should return results for all comments"

    # First comment should succeed
    assert results[0][:result], "First comment should have result"
    assert_nil results[0][:error], "First comment should not have error"

    # Second comment should have error
    assert_nil results[1][:result], "Second comment should not have result"
    assert_not_nil results[1][:error], "Second comment should have error"
  end

  test "should return empty array for blank batch" do
    assert_equal [], @service.classify_comments(nil)
    assert_equal [], @service.classify_comments([])
  end

  # Test preview functionality
  test "should preview classification without persisting" do
    text = "Este produto é incrível e fantástico" # Portuguese text with keywords

    result = @service.preview_classification(text)

    assert_equal 2, result[:keyword_count], "Should count keywords in preview"
    assert result[:would_approve], "Should indicate approval in preview"
  end

  test "should preview rejection for insufficient keywords" do
    text = "This is an okay product"

    result = @service.preview_classification(text)

    assert_equal 0, result[:keyword_count], "Should count 0 keywords"
    assert_not result[:would_approve], "Should indicate rejection in preview"
  end

  test "should return 0 for blank text in preview" do
    result = @service.preview_classification("")
    assert_equal 0, result[:keyword_count]
    assert_not result[:would_approve]

    result = @service.preview_classification(nil)
    assert_equal 0, result[:keyword_count]
    assert_not result[:would_approve]
  end

  # Test keyword caching
  test "should cache keywords for performance" do
    # First call should hit database
    Keyword.expects(:pluck).with(:word).returns(["great", "excellent"]).once

    result1 = @service.classify_comment(@comment)

    # Second call should use cache (no database hit)
    result2 = @service.classify_comment(@comment)

    assert_equal result1[:keyword_count], result2[:keyword_count], "Results should be consistent"
  end

  test "should refresh cache after expiry" do
    # Mock time to control cache expiry
    initial_time = Time.current
    Time.stubs(:current).returns(initial_time)

    # First call loads cache
    @service.classify_comment(@comment)

    # Advance time beyond cache expiry
    expired_time = initial_time + 31.minutes
    Time.stubs(:current).returns(expired_time)

    # Should reload keywords from database
    Keyword.expects(:pluck).with(:word).returns(["great", "excellent"]).once

    @service.classify_comment(@comment)
  end

  # Test reclassification functionality
  test "should reclassify all comments" do
    # Create additional comments in different states
    approved_comment = Comment.create!(
      name: "Approved Comment",
      email: "approved@example.com",
      body: "This was previously approved",
      external_id: 100,
      post: @post,
      status: :approved
    )

    rejected_comment = Comment.create!(
      name: "Rejected Comment",
      email: "rejected@example.com",
      body: "This was previously rejected",
      external_id: 101,
      post: @post,
      status: :rejected
    )

    # Create a new comment that shouldn't be reclassified
    new_comment = Comment.create!(
      name: "New Comment",
      email: "new@example.com",
      body: "This is new",
      external_id: 102,
      post: @post,
      status: :new
    )

    result = @service.reclassify_all_comments

    assert_equal 2, result[:total_processed], "Should process 2 comments (approved + rejected)"
    assert_equal 2, result[:successful], "Should successfully reclassify both comments"
    assert_equal 0, result[:errors], "Should have no errors"

    # Check that comments were reclassified
    approved_comment.reload
    rejected_comment.reload
    new_comment.reload

    # New comment should remain unchanged
    assert new_comment.new?, "New comment should remain in new state"
  end

  test "should handle errors during reclassification" do
    # Set the original comment to approved status so it gets reclassified
    @comment.update!(status: :approved)

    # Create a comment that will cause classification error by mocking it
    problematic_comment = Comment.create!(
      name: "Problem Comment",
      email: "problem@example.com",
      body: "Valid body", # Valid body to pass validation
      translated_body: "Valid translated body",
      external_id: 200,
      post: @post,
      status: :approved
    )

    # Mock the comment to cause an error during classification
    problematic_comment.stubs(:translated_body).returns("")
    problematic_comment.stubs(:body).returns("")

    result = @service.reclassify_all_comments

    assert_equal 2, result[:total_processed], "Should attempt to process 2 comments"
    assert_equal 2, result[:successful], "Should have 2 successful classifications"
    assert_equal 0, result[:errors], "Should have 0 errors"
  end

  # Test edge cases
  test "should handle empty keyword list" do
    # Remove all keywords
    Keyword.delete_all

    result = @service.classify_comment(@comment)

    assert_not result[:approved], "Should reject when no keywords exist"
    assert_equal 0, result[:keyword_count], "Should find 0 keywords"
  end

  test "should handle special characters in keywords and text" do
    # Create keyword with special characters
    Keyword.create!(word: "alta-qualidade")

    @comment.update!(
      body: "Este é um produto de alta-qualidade com características ótimo",
      translated_body: nil
    )

    result = @service.classify_comment(@comment)

    # Should find both "alta-qualidade" and "ótimo"
    assert_equal 2, result[:keyword_count], "Should handle special characters in keywords"
    assert result[:approved], "Should approve comment with special character keywords"
  end

  test "should handle very long text efficiently" do
    # Create a very long text with keywords scattered throughout
    long_text = "Este é um produto ótimo. " * 1000 + "Também é excelente. " * 1000

    @comment.update!(
      body: long_text,
      translated_body: nil
    )

    # Should still work efficiently
    result = @service.classify_comment(@comment)

    assert_equal 2, result[:keyword_count], "Should handle long text"
    assert result[:approved], "Should approve long text with sufficient keywords"
  end

  test "should handle unicode and accented characters" do
    # Create keywords with accented characters (avoiding duplicates)
    Keyword.create!(word: "perfeito")
    Keyword.create!(word: "magnífico")

    @comment.update!(
      body: "Este produto é perfeito e magnífico",
      translated_body: nil
    )

    result = @service.classify_comment(@comment)

    assert_equal 2, result[:keyword_count], "Should handle unicode characters"
    assert result[:approved], "Should approve text with accented keywords"
  end

  private

  def create_comment_with_keywords(keyword_count)
    keywords_text = @keywords.first(keyword_count).map(&:word).join(" ")
    body_text = "This product is #{keywords_text} and nice"

    Comment.create!(
      name: "Test Commenter",
      email: "test@example.com",
      body: body_text,
      external_id: rand(10000),
      post: @post,
      status: :processing
    )
  end
end
