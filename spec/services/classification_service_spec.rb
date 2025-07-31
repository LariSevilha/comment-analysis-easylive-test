require 'rails_helper'

RSpec.describe ClassificationService, type: :service do
  let(:service) { described_class.new }
  let(:user)    { create(:user) }
  let(:post)    { create(:post, user: user) }

  # Mock keywords for testing
  before do
    allow(Keyword).to receive(:pluck).with(:word).and_return([
      'bom', 'excelente', 'ótimo', 'perfeito', 'maravilhoso', 'fantástico', 'incrível', 'amor'
    ])
  end

  describe '#classify_comment' do
    context 'quando o texto tem 2 palavras-chave' do
      it 'aprova o comentário' do
        # Create comment in processing state (which is likely the valid initial state)
        comment = create(:comment, post: post, translated_body: 'Texto excelente e maravilhoso', status: 'processing')
        
        result = service.classify_comment(comment)

        expect(comment.reload).to be_approved
        expect(result[:approved]).to be true
        expect(result[:keyword_count]).to eq(2)
      end
    end

    context 'quando o texto tem apenas 1 palavra-chave' do
      it 'rejeita o comentário' do
        comment = create(:comment, post: post, translated_body: 'Texto maravilhoso', status: 'processing')

        result = service.classify_comment(comment)

        expect(comment.reload).to be_rejected
        expect(result[:approved]).to be false
        expect(result[:keyword_count]).to eq(1)
      end
    end

    context 'quando o texto não tem palavras-chave' do
      it 'rejeita o comentário' do
        comment = create(:comment, post: post, translated_body: 'Texto neutro sem palavras positivas', status: 'processing')

        result = service.classify_comment(comment)

        expect(comment.reload).to be_rejected
        expect(result[:approved]).to be false
        expect(result[:keyword_count]).to eq(0)
      end
    end

    context 'quando o comentário não pode ser aprovado' do
      it 'não muda o status se não pode aprovar' do
        comment = create(:comment, post: post, translated_body: 'Texto excelente e maravilhoso', status: 'approved')
        
        # Mock the state machine methods
        allow(comment).to receive(:may_approve?).and_return(false)
        allow(comment).to receive(:may_reject?).and_return(false)

        result = service.classify_comment(comment)

        expect(result[:keyword_count]).to eq(2)
        # Status should remain approved since it can't transition
        expect(comment.reload.status).to eq('approved')
      end
    end

    context 'quando o comentário é nil' do
      it 'levanta erro ClassificationError' do
        expect {
          service.classify_comment(nil)
        }.to raise_error(ClassificationService::ClassificationError, "Comment cannot be nil")
      end
    end

    context 'quando o comentário não está persistido' do
      it 'levanta erro ClassificationError' do
        comment = build(:comment, post: post, translated_body: 'Texto excelente')
        
        expect {
          service.classify_comment(comment)
        }.to raise_error(ClassificationService::ClassificationError, "Comment must be persisted")
      end
    end

    context 'quando o comentário não tem texto para análise' do
      it 'levanta erro ClassificationError' do
        comment = create(:comment, post: post, body: 'original text', translated_body: nil, status: 'processing')
        
        # Mock both body and translated_body to return blank/nil
        allow(comment).to receive(:translated_body).and_return(nil)
        allow(comment).to receive(:body).and_return('')
        
        expect {
          service.classify_comment(comment)
        }.to raise_error(ClassificationService::ClassificationError, "Failed to classify comment: Comment has no text to analyze")
      end
    end
  end

  describe '#classify_comments' do
    it 'processa múltiplos comentários' do
      comment1 = create(:comment, post: post, translated_body: 'Texto excelente e maravilhoso', status: 'processing')
      comment2 = create(:comment, post: post, translated_body: 'Texto ruim', status: 'processing')
      
      results = service.classify_comments([comment1, comment2])

      expect(results.size).to eq(2)
      expect(results[0][:comment_id]).to eq(comment1.id)
      expect(results[0][:result][:approved]).to be true
      expect(results[1][:comment_id]).to eq(comment2.id)
      expect(results[1][:result][:approved]).to be false
    end

    it 'retorna array vazio para lista vazia' do
      results = service.classify_comments([])
      expect(results).to eq([])
    end

    it 'lida com erros individuais' do
      comment1 = create(:comment, post: post, translated_body: 'Texto excelente', status: 'processing')
      
      # Test with a valid comment and simulate an error for the second item
      results = service.classify_comments([comment1])
      
      # Now test error handling by mocking an exception
      allow(service).to receive(:classify_comment).and_raise(ClassificationService::ClassificationError.new("Test error"))
      
      results_with_error = service.classify_comments([comment1])

      expect(results_with_error.size).to eq(1)
      expect(results_with_error[0][:comment_id]).to eq(comment1.id)
      expect(results_with_error[0][:error]).to eq("Test error")
    end
  end

  describe '#preview_classification' do
    it 'retorna preview para texto com keywords suficientes' do
      result = service.preview_classification('Texto excelente e maravilhoso')
      
      expect(result[:keyword_count]).to eq(2)
      expect(result[:would_approve]).to be true
    end

    it 'retorna preview para texto sem keywords suficientes' do
      result = service.preview_classification('Texto neutro')
      
      expect(result[:keyword_count]).to eq(0)
      expect(result[:would_approve]).to be false
    end

    it 'lida com texto vazio' do
      result = service.preview_classification('')
      
      expect(result[:keyword_count]).to eq(0)
      expect(result[:would_approve]).to be false
    end

    it 'lida com texto nil' do
      result = service.preview_classification(nil)
      
      expect(result[:keyword_count]).to eq(0)
      expect(result[:would_approve]).to be false
    end
  end

  describe '#reclassify_all_comments' do
    it 'reclassifica todos os comentários' do
      comment1 = create(:comment, post: post, translated_body: 'Texto excelente e maravilhoso', status: 'approved')
      comment2 = create(:comment, post: post, translated_body: 'Texto ruim', status: 'rejected')
      
      # Mock the Comment scope chain properly
      relation_mock = double('ActiveRecord::Relation')
      allow(Comment).to receive(:where).with(status: [:approved, :rejected]).and_return(relation_mock)
      allow(relation_mock).to receive(:count).and_return(2)
      
      # Mock find_each.with_index properly
      allow(relation_mock).to receive(:find_each).and_return(relation_mock)
      allow(relation_mock).to receive(:with_index) do |&block|
        block.call(comment1, 0)
        block.call(comment2, 1)
      end
      
      # Allow update! to be called with different arguments
      allow(comment1).to receive(:update!).with(status: :processing).and_call_original
      allow(comment1).to receive(:update!).with(keyword_count: 2).and_call_original
      allow(comment2).to receive(:update!).with(status: :processing).and_call_original
      allow(comment2).to receive(:update!).with(keyword_count: 0).and_call_original
      
      result = service.reclassify_all_comments

      expect(result[:total_processed]).to eq(2)
      expect(result[:successful]).to eq(2)
      expect(result[:errors]).to eq(0)
      expect(comment1.reload.status).to eq('approved') # Assuming 2 keywords lead to approval
      expect(comment2.reload.status).to eq('rejected') # Assuming 0 keywords lead to rejection
    end
    
    it 'lida com erros durante reclassificação' do
      comment1 = create(:comment, post: post, translated_body: 'Texto test', status: 'approved')
      
      # Mock the Comment scope chain
      relation_mock = double('ActiveRecord::Relation')
      allow(Comment).to receive(:where).with(status: [:approved, :rejected]).and_return(relation_mock)
      allow(relation_mock).to receive(:count).and_return(1)
      
      # Mock find_each.with_index to yield the comment
      allow(relation_mock).to receive(:find_each).and_return(relation_mock)
      allow(relation_mock).to receive(:with_index) do |&block|
        block.call(comment1, 0)
      end
      
      # Mock update! to succeed but classify_comment to fail
      allow(comment1).to receive(:update!).with(status: :processing)
      allow(service).to receive(:classify_comment).with(comment1).and_raise(StandardError.new("Test error"))
      
      result = service.reclassify_all_comments

      expect(result[:total_processed]).to eq(1)
      expect(result[:successful]).to eq(0)
      expect(result[:errors]).to eq(1)
    end
  end

  describe 'private methods' do
    describe '#count_keywords_in_text' do
      it 'conta keywords com word boundaries' do
        # Test the private method via public interface
        comment = create(:comment, post: post, translated_body: 'excelente texto excelente', status: 'processing')
        
        result = service.classify_comment(comment)
        
        # Should count 'excelente' only once due to unique keyword counting
        expect(result[:keyword_count]).to eq(1)
      end

      it 'é case insensitive' do
        comment = create(:comment, post: post, translated_body: 'EXCELENTE e MARAVILHOSO', status: 'processing')
        
        result = service.classify_comment(comment)
        
        expect(result[:keyword_count]).to eq(2)
      end

      it 'usa word boundaries para matching preciso' do
        comment = create(:comment, post: post, translated_body: 'inexcelente amaravilhoso', status: 'processing')
        
        result = service.classify_comment(comment)
        
        # Should not match partial words
        expect(result[:keyword_count]).to eq(0)
      end
    end
  end
end