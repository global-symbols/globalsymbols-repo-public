class SetUserIdNullableOnComments < ActiveRecord::Migration[5.2]
  def change
    change_column_null :comments, :user_id, true
  end
end
