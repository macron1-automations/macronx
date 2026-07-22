class InboxesController < ApplicationController
  before_action :set_inbox, only: %i[show edit update destroy process_modal mark_processed archive unarchive tag_modal mark_tagged]

  def index
    inboxes = current_user.inboxes
    @counts = {
      unprocessed: inboxes.unprocessed.count,
      processed: inboxes.processed_items.count,
      archived: inboxes.archived.count
    }
    @tags = Tag.order(:name)

    @inboxes = case params[:filter]
    when "processed" then inboxes.processed_items
    when "archived"  then inboxes.archived
    else                  inboxes.unprocessed
    end

    if params[:query].present?
      q = "%#{params[:query]}%"
      @inboxes = @inboxes.where("name ILIKE ? OR source ILIKE ? OR summary ILIKE ?", q, q, q)
    end

    @inboxes = @inboxes.where("source ILIKE ?", "%#{params[:source]}%") if params[:source].present?
    @inboxes = @inboxes.where(tag_id: params[:tag]) if params[:tag].present?

    sort_col = %w[name source created_at].include?(params[:sort]) ? params[:sort] : "created_at"
    direction = params[:direction] == "asc" ? :asc : :desc
    @inboxes = @inboxes.with_attached_attachments.includes(:tag).order(sort_col => direction)
  end

  def bulk_process_modal
    @inbox_ids = selected_inboxes.ids
    @workflows = Workflow.order(:name)
    render :bulk_process
  end

  def bulk_process
    workflow_id = params.dig(:inbox, :workflow_id)
    return redirect_to inboxes_path, alert: "Please select a workflow." if workflow_id.blank?

    count = selected_inboxes.update_all(processed: true, workflow_id: workflow_id)
    redirect_to inboxes_path, notice: "#{count} item(s) processed."
  end

  def bulk_archive
    count = selected_inboxes.update_all(archived: true)
    redirect_to inboxes_path, notice: "#{count} item(s) archived."
  end

  def bulk_unarchive
    count = selected_inboxes.update_all(archived: false)
    redirect_to inboxes_path(filter: "archived"), notice: "#{count} item(s) restored to inbox."
  end

  def bulk_destroy
    selected_inboxes.destroy_all
    redirect_to inboxes_path, notice: "Items deleted."
  end

  def bulk_tag_modal
    @inbox_ids = selected_inboxes.ids
    @tags = Tag.order(:name)
    render :bulk_tag
  end

  def bulk_tag
    tag_id = params.dig(:inbox, :tag_id).presence
    count = selected_inboxes.update_all(tag_id: tag_id)
    redirect_to inboxes_path, notice: "#{count} item(s) tagged."
  end

  def show
  end

  def new
    @inbox = current_user.inboxes.new(payload: {}, metadata: {})
    @tags = Tag.order(:name)
    populate_json_text_fields
  end

  def create
    @inbox = current_user.inboxes.new(inbox_params_without_attachments)

    if @inbox.save
      attach_new_files
      redirect_to @inbox, notice: "Inbox was successfully created."
    else
      @tags = Tag.order(:name)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @tags = Tag.order(:name)
    populate_json_text_fields
  end

  def update
    purge_attachments
    attach_new_files

    if @inbox.update(inbox_update_params)
      redirect_to @inbox, notice: "Inbox was successfully updated."
    else
      @tags = Tag.order(:name)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @inbox.destroy
    redirect_to inboxes_path, notice: "Inbox was successfully deleted."
  end

  def process_modal
    @workflows = Workflow.order(:name)
    render :process
  end

  def mark_processed
    if @inbox.update(processed: true, workflow_id: params.dig(:inbox, :workflow_id))
      redirect_to inboxes_path, notice: "Inbox item successfully processed."
    else
      @workflows = Workflow.order(:name)
      render :process, status: :unprocessable_content
    end
  end

  def archive
    @inbox.update(archived: true)
    redirect_to inboxes_path, notice: "Inbox item archived."
  end

  def unarchive
    @inbox.update(archived: false)
    redirect_to inboxes_path(filter: "archived"), notice: "\"#{@inbox.name}\" restored to inbox."
  end

  def tag_modal
    @tags = Tag.order(:name)
    render :tag
  end

  def mark_tagged
    tag_id = params.dig(:inbox, :tag_id).presence
    @inbox.update(tag_id: tag_id)
    redirect_to @inbox, notice: "Tag updated."
  end

  private

  def set_inbox
    @inbox = current_user.inboxes.find(params[:id])
  end

  def selected_inboxes
    current_user.inboxes.where(id: Array(params[:inbox_ids]))
  end

  def populate_json_text_fields
    @inbox.payload_text  = JSON.pretty_generate(@inbox.payload  || {})
    @inbox.metadata_text = JSON.pretty_generate(@inbox.metadata || {})
  end

  def inbox_params
    params.require(:inbox).permit(:name, :source, :summary, :body, :tag_id, :payload_text, :metadata_text, attachments: [])
  end

  def inbox_update_params
    inbox_params_without_attachments
  end

  def inbox_params_without_attachments
    inbox_params.except(:attachments)
  end

  def attach_new_files
    files = new_attachment_files
    return if files.empty?

    @inbox.attachments.attach(files)
  end

  def new_attachment_files
    Array(params.dig(:inbox, :attachments)).select { |file| file.is_a?(ActionDispatch::Http::UploadedFile) }
  end

  def purge_attachments
    signed_ids = Array(params.dig(:inbox, :purge_attachment_signed_ids)).compact_blank
    return if signed_ids.empty?

    signed_ids.each do |signed_id|
      attachment = @inbox.attachments.find { |a| a.blob.signed_id == signed_id }
      attachment&.purge
    end
  end
end
