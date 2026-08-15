class AddSummaryPromptToWorkflows < ActiveRecord::Migration[8.1]
  def change
    add_column :workflows, :summary_prompt, :text
  end
end
