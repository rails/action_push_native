# This file is the gem entrypoint required by the "actionpush" gemspec.
# Zeitwerk expects the top-level module "ActionPush" to be defined in "action_push.rb".
# we define a dummy 'Actionpush' module here to match the gem name,
# and manually require 'action_push.rb' to load the actual namespace.
module Actionpush;end
require "action_push"
