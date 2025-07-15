class Api::V1::KeywordsController < ApplicationController
  def index
    keywords = Keyword.active.order(:word)
    
    render json: {
      keywords: keywords.map { |k| { id: k.id, word: k.word } },
      total: keywords.count
    }
  end
  
  def create
    keyword = Keyword.new(keyword_params)
    
    if keyword.save
      render json: { 
        message: "Keyword '#{keyword.word}' created successfully",
        keyword: { id: keyword.id, word: keyword.word }
      }, status: :created
    else
      render json: { errors: keyword.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def update
    keyword = Keyword.find(params[:id])
    
    if keyword.update(keyword_params)
      render json: { 
        message: "Keyword updated successfully",
        keyword: { id: keyword.id, word: keyword.word }
      }
    else
      render json: { errors: keyword.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    keyword = Keyword.find(params[:id])
    keyword.destroy
    
    render json: { message: "Keyword '#{keyword.word}' deleted successfully" }
  end
  
  private
  
  def keyword_params
    params.require(:keyword).permit(:word)
  end
end
