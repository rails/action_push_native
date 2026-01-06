class CreateActionPushNativeDevice < ActiveRecord::Migration[7.1]
  def change
    create_table :action_push_native_devices do |t|
      t.string :name
      t.string :platform, null: false
      t.string :token, null: false
      t.belongs_to :owner, polymorphic: true

      t.timestamps
    end
  end
end
