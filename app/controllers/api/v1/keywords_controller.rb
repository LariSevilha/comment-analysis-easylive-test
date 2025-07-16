class Api::V1::KeywordsController < ApplicationController
  before_action :set_keyword, only: [:update, :destroy]

  def index
    keywords = Keyword.all.order(:word)
    render json: {
      keywords: keywords.map do |keyword|
        {
          id: keyword.id,
          word: keyword.word,
          active: keyword.active,
          description: keyword.description,
          created_at: keyword.created_at,
          updated_at: keyword.updated_at
        }
      end
    }
  end

  def create
    keyword = Keyword.new(keyword_params)
    
    if keyword.save
      render json: {
        keyword: {
          id: keyword.id,
          word: keyword.word,
          active: keyword.active,
          description: keyword.description
        },
        message: 'Keyword created successfully'
      }, status: :created
    else
      render json: {
        errors: keyword.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
    if @keyword.update(keyword_params)
      render json: {
        keyword: {
          id: @keyword.id,
          word: @keyword.word,
          active: @keyword.active,
          description: @keyword.description
        },
        message: 'Keyword updated successfully'
      }
    else
      render json: {
        errors: @keyword.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def destroy
    @keyword.destroy
    render json: {
      message: 'Keyword deleted successfully'
    }
  end

  private

  def set_keyword
    @keyword = Keyword.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Keyword not found' }, status: :not_found
  end

  def keyword_params
    params.require(:keyword).permit(:word, :active, :description)
  end
end