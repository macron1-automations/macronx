class WorkflowsController < ApplicationController
  before_action :set_workflow, only: %i[show edit update destroy]

  def index
    @workflows = Workflow.order(:name)
    @workflow_inbox_counts = current_user.inboxes.group(:workflow_id).count
  end

  def show
    @inboxes = current_user.inboxes.where(workflow: @workflow).order(created_at: :desc)
  end

  def new
    @workflow = Workflow.new
    @tags = Tag.order(:name)
  end

  def create
    @workflow = Workflow.new(workflow_params)

    if @workflow.save
      redirect_to @workflow, notice: "Workflow was successfully created."
    else
      @tags = Tag.order(:name)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @tags = Tag.order(:name)
  end

  def update
    if @workflow.update(workflow_params)
      redirect_to @workflow, notice: "Workflow was successfully updated."
    else
      @tags = Tag.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @workflow.destroy
    redirect_to workflows_path, notice: "Workflow was successfully deleted."
  end

  private

  def set_workflow
    @workflow = Workflow.find(params[:id])
  end

  def workflow_params
    params.require(:workflow).permit(:name, :prompt, :summary_prompt, :tag_id)
  end
end
