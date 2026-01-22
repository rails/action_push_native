# frozen_string_literal: true

module ActionPushNative
  class Record < ActiveRecord::Base
    self.abstract_class = true
  end
end

ActiveSupport.run_load_hooks :action_push_native_record, ActionPushNative::Record
