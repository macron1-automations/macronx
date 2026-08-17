class AddIncludeAttachmentsToWorkflows < ActiveRecord::Migration[8.1]
  def change
    add_column :workflows, :include_attachments, :boolean, default: false, null: false
  end
end
