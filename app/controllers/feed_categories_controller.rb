class FeedCategoriesController < ApplicationController
  before_action :set_feed_category, only: %i[show edit update destroy]

  def index
    @feed_categories = FeedCategory.order(:name)
    @feed_counts = Feed.group(:feed_category_id).count
  end

  def show
    @feeds = @feed_category.feeds.order(:title)
  end

  def new
    @feed_category = FeedCategory.new
  end

  def create
    @feed_category = FeedCategory.new(feed_category_params)

    if @feed_category.save
      redirect_to @feed_category, notice: "Feed category was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @feed_category.update(feed_category_params)
      redirect_to @feed_category, notice: "Feed category was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @feed_category.destroy
      redirect_to feed_categories_path, notice: "Feed category was successfully deleted."
    else
      redirect_to @feed_category, alert: "Feed category cannot be deleted while feeds are assigned."
    end
  end

  private

  def set_feed_category
    @feed_category = FeedCategory.find(params[:id])
  end

  def feed_category_params
    params.require(:feed_category).permit(:name)
  end
end
