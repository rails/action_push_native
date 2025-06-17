# This migration comes from action_native_push (originally 20250610075650)
class CreateActionNativePushDevice < ActiveRecord::Migration[8.0]
  def change
    create_table :action_native_push_devices do |t|
      t.string :name
      t.string :application, null: false
      t.string :token, null: false
      t.belongs_to :record, polymorphic: true

      t.timestamps
    end
  end
end
