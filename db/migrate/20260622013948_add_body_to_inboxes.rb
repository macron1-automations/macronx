class AddBodyToInboxes < ActiveRecord::Migration[8.1]
  def change
    add_column :inboxes, :body, :text
  end
end
