class TagsController < ApplicationController
  before_action :set_tag, only: %i[show edit update destroy]

  def index
    @tags = Tag.order(:name)
    @tag_inbox_counts = current_user.inboxes.group(:tag_id).count
  end

  def show
    @inboxes = current_user.inboxes.where(tag: @tag).order(created_at: :desc)
    @workflows = @tag.workflows.order(:name)
  end

  def new
    @tag = Tag.new
  end

  def create
    @tag = Tag.new(tag_params)

    if @tag.save
      redirect_to @tag, notice: "Tag was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @tag.update(tag_params)
      redirect_to @tag, notice: "Tag was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tag.destroy
    redirect_to tags_path, notice: "Tag was successfully deleted."
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def tag_params
    params.require(:tag).permit(:name, :color)
  end
end
