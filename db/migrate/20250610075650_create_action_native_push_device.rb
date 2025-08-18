class CreateActionNativePushDevice < ActiveRecord::Migration[8.0]
  def change
    create_table :action_native_push_devices do |t|
      t.string :name
      t.string :platform, null: false
      t.string :token, null: false
      t.belongs_to :owner, polymorphic: true

      t.timestamps
    end
  end
end
