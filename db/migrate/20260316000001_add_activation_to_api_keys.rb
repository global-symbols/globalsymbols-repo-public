class AddActivationToAPIKeys < ActiveRecord::Migration[6.1]
  def up
    add_column :api_keys, :activation_token, :string
    add_column :api_keys, :activation_sent_at, :datetime
    add_column :api_keys, :activated_at, :datetime

    add_index :api_keys, :activation_token, unique: true

    execute <<~SQL.squish
      UPDATE api_keys
      SET activated_at = created_at
      WHERE revoked_at IS NULL
        AND activated_at IS NULL
    SQL
  end

  def down
    remove_index :api_keys, :activation_token
    remove_column :api_keys, :activation_token
    remove_column :api_keys, :activation_sent_at
    remove_column :api_keys, :activated_at
  end
end

