class ChangeUriBaseOnCodingFrameworks < ActiveRecord::Migration[5.2]
  def change
    rename_column :coding_frameworks, :uri_base, :api_uri_base
    add_column :coding_frameworks, :www_uri_base, :string, after: :api_uri_base
  end
end
