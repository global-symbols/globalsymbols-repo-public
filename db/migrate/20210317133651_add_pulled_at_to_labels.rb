class AddPulledAtToLabels < ActiveRecord::Migration[6.0]
  def change
    add_column :labels, :pulled_at, :datetime, after: :description
  end
end
