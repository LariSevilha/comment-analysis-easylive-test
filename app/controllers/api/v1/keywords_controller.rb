class Api::V1::KeywordsController < Api::V1::BaseController
  before_action :set_keyword, only: [:show, :update, :destroy]
  
  def index
    keywords = Keyword.active.order(:word)
    render_success(keywords.map(&:attributes))
  end
  
  def show
    render_success(@keyword.attributes)
  end
  
  def create
    keyword = Keyword.new(keyword_params)
    
    if keyword.save
      render_success(keyword.attributes, 'Keyword created successfully')
    else
      render_error(keyword.errors.full_messages.join(', '))
    end
  end
  
  def update
    if @keyword.update(keyword_params)
      render_success(@keyword.attributes, 'Keyword updated successfully')
    else
      render_error(@keyword.errors.full_messages.join(', '))
    end
  end
  
  def destroy
    @keyword.destroy
    render_success(nil, 'Keyword deleted successfully')
  end
  
  private
  
  def set_keyword
    @keyword = Keyword.find(params[:id])
  end
  
  
  def keyword_params
    params.require(:keyword).permit(:word, :active)
  end
end