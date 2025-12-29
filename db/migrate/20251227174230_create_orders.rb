class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.integer :status, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.datetime :processed_at

      t.timestamps
    end
  end
end
