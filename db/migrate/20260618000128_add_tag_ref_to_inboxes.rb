class AddTagRefToInboxes < ActiveRecord::Migration[8.1]
  def change
    add_reference :inboxes, :tag, null: true, foreign_key: true
  end
end
