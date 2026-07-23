class CreateFeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :feeds do |t|
      t.string :title, null: false
      t.string :feed_url, null: false
      t.references :feed_category, null: false, foreign_key: true

      t.timestamps
    end

    add_index :feeds, :feed_url, unique: true
  end
end
