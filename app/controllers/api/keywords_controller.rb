class Api::KeywordsController < ApplicationController
  before_action :set_keyword, only: [:show, :update, :destroy]

  # GET /api/keywords
  def index
    keywords = CacheManager.fetch('all', cache_type: :keywords) do
      Keyword.all.order(:word).pluck(:id, :word).map { |id, word| { id: id, word: word } }
    end

    render json: { keywords: keywords }
  end

  # GET /api/keywords/:id
  def show
    render json: { keyword: { id: @keyword.id, word: @keyword.word } }
  end

  # POST /api/keywords
  def create
    @keyword = Keyword.new(keyword_params)

    if @keyword.save
      invalidate_keywords_cache
      render json: { keyword: { id: @keyword.id, word: @keyword.word } }, status: :created
    else
      render json: { error: { code: 'VALIDATION_ERROR', message: @keyword.errors.full_messages.join(', ') } }, status: :unprocessable_entity
    end
  end

  # PUT/PATCH /api/keywords/:id
  def update
    if @keyword.update(keyword_params)
      invalidate_keywords_cache
      render json: { keyword: { id: @keyword.id, word: @keyword.word } }
    else
      render json: { error: { code: 'VALIDATION_ERROR', message: @keyword.errors.full_messages.join(', ') } }, status: :unprocessable_entity
    end
  end

  # DELETE /api/keywords/:id
  def destroy
    @keyword.destroy
    invalidate_keywords_cache
    render json: { message: 'Keyword deleted successfully' }
  end

  private

  def set_keyword
    @keyword = Keyword.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: { code: 'NOT_FOUND', message: 'Keyword not found' } }, status: :not_found
  end

  def keyword_params
    params.require(:keyword).permit(:word)
  end

  def invalidate_keywords_cache
    CacheManager.invalidate_related_caches(:keyword_change)
  end
end
