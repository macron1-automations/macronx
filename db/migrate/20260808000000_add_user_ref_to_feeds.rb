class AddUserRefToFeeds < ActiveRecord::Migration[8.1]
  def up
    add_reference :feeds, :user, foreign_key: true, null: true
    backfill_user_ownership
    change_column_null :feeds, :user_id, false
  end

  def down
    remove_reference :feeds, :user, foreign_key: true
  end

  private

  def backfill_user_ownership
    owner = first_owner
    return unless owner

    execute(<<~SQL)
      UPDATE feeds SET user_id = #{owner.id} WHERE user_id IS NULL
    SQL
  end

  def first_owner
    admin = User.where(admin: true).order(:created_at).first
    admin || User.order(:created_at).first
  end
end
