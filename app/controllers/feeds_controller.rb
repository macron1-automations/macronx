class FeedsController < ApplicationController
  before_action :set_feed, only: %i[show edit update destroy]
  before_action :set_feed_categories, only: %i[new create edit update]

  def index
    @feeds = Feed.includes(:feed_category).order(:title)
  end

  def show
  end

  def new
    @feed = Feed.new
  end

  def create
    @feed = Feed.new(feed_params)

    if @feed.save
      redirect_to @feed, notice: "Feed was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @feed.update(feed_params)
      redirect_to @feed, notice: "Feed was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @feed.destroy
    redirect_to feeds_path, notice: "Feed was successfully deleted."
  end

  private

  def set_feed
    @feed = Feed.find(params[:id])
  end

  def set_feed_categories
    @feed_categories = FeedCategory.order(:name)
  end

  def feed_params
    params.require(:feed).permit(:title, :feed_url, :feed_category_id)
  end
end
