class AddUniqueIndexToActionPushNativeDevicesToken < ActiveRecord::Migration[7.2]
  # A device is identified by its push token, so two rows sharing a token
  # deliver duplicate notifications (delivery sends once per device row). Apps
  # that register tokens with find_or_create_by(token:) can also race concurrent
  # registrations into duplicate rows — Hotwire Native re-sends the token on
  # nearly every navigation, once per WebView — so the constraint belongs at the
  # database. Shipped as an additive migration (rather than amending the
  # create-table migration) so existing installs pick it up via
  # `bin/rails action_push_native:install:migrations`.
  def up
    remove_duplicate_tokens
    add_index :action_push_native_devices, :token, unique: true
  end

  def down
    remove_index :action_push_native_devices, :token
  end

  private
    # Keep one row per token (the highest id — i.e. the most recently inserted)
    # and drop the rest; the unique index cannot build while duplicates remain.
    # The removed rows are exact duplicates that were only ever causing
    # duplicate deliveries. The derived-table wrapper keeps this portable across
    # PostgreSQL, MySQL, and SQLite.
    def remove_duplicate_tokens
      execute(<<~SQL)
        DELETE FROM action_push_native_devices
        WHERE id NOT IN (
          SELECT keep_id FROM (
            SELECT MAX(id) AS keep_id
            FROM action_push_native_devices
            GROUP BY token
          ) AS keepers
        )
      SQL
    end
end
