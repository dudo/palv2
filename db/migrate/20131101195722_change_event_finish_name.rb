class ChangeEventFinishName < ActiveRecord::Migration
  def change
    rename_column :events, :end, :finish
  end
end
