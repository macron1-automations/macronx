class CreateFeedImports < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :source_filename, null: false
      t.jsonb :imported_rows, null: false, default: []
      t.jsonb :unimported_rows, null: false, default: []
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at

      t.timestamps
    end

    add_index :feed_imports, :status
    add_index :feed_imports, [ :user_id, :created_at ]
  end
end
