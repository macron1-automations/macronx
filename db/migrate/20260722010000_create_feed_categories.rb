class CreateFeedCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_categories do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :feed_categories, "LOWER(name)", unique: true,
      name: "index_feed_categories_on_lower_name"
  end
end
