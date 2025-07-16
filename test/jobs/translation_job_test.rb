require 'test_helper'

class TranslationJobTest < ActiveJob::TestCase
  def setup
    @comment = comments(:one)
    @job_tracker = JobTracker.create!(
      job_id: SecureRandom.uuid,
      status: :processing,
      progress: 50,
      total: 100
    )
  end

  test "should enqueue translation job" do
    assert_enqueued_with(job: TranslationJob, args: [@comment.id, @job_tracker.id]) do
      TranslationJob.perform_later(@comment.id, @job_tracker.id)
    end
  end

  test "should translate and classify comment successfully" do
    # Mock services
    translation_service = mock('translation_service')
    classification_service = mock('classification_service')

    TranslationService.expects(:new).returns(translation_service)
    ClassificationService.expects(:new).returns(classification_service)

    # Mock translation
    translated_text = "Texto traduzido"
    translation_service.expects(:translate_to_portuguese).with(@comment.body).returns(translated_text)

    # Mock classification
    classification_result = { approved: true, keyword_count: 3, status: 'approved' }
    classification_service.expects(:classify_comment).with(@comment).returns(classification_result)

    perform_enqueued_jobs do
      TranslationJob.perform_later(@comment.id, @job_tracker.id)
    end

    @comment.reload
    assert_equal translated_text, @comment.translated_body
  end

  test "should handle translation service errors and fallback to classification" do
    # Mock services
    translation_service = mock('translation_service')
    classification_service = mock('classification_service')

    TranslationService.expects(:new).returns(translation_service)
    ClassificationService.expects(:new).returns(classification_service).twice # Called twice: once normally, once in rescue

    # Mock translation failure with a non-retryable error
    translation_service.expects(:translate_to_portuguese)
                      .with(@comment.body)
                      .raises(TranslationService::TranslationError.new("Translation failed"))

    # Mock classification with original text (fallback behavior)
    classification_result = { approved: false, keyword_count: 1, status: 'rejected' }
    classification_service.expects(:classify_comment).with(@comment).returns(classification_result)

    # The job should handle the error gracefully and still classify the comment
    perform_enqueued_jobs do
      TranslationJob.perform_later(@comment.id, @job_tracker.id)
    end

    @comment.reload
    # Comment should still be processed even if translation failed
    assert_not_nil @comment.status
  end
end
