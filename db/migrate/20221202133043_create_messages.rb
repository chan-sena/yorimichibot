class CreateMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :messages do |t|
      t.string :departure
      t.string :destination

      t.timestamps
    end
  end
end
