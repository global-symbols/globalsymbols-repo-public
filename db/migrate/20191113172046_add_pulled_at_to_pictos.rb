class AddPulledAtToPictos < ActiveRecord::Migration[5.2]
  def change
    add_column :pictos, :pulled_at, :datetime, after: :visibility
  end
end
