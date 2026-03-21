class CreateApiKeys < ActiveRecord::Migration[6.1]
  def change
    create_table :api_keys do |t|
      t.string :key_digest, null: false
      t.string :user_type, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.text :purpose
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.string :activation_token
      t.datetime :activation_sent_at
      t.datetime :activated_at

      t.timestamps
    end

    add_index :api_keys, :activation_token, unique: true
    add_index :api_keys, :key_digest, unique: true
  end
end
