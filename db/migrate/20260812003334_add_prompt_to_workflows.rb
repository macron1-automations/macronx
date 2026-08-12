class AddPromptToWorkflows < ActiveRecord::Migration[8.1]
  def change
    add_column :workflows, :prompt, :text
  end
end
