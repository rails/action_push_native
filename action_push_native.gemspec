# frozen_string_literal: true

require_relative "lib/action_push_native/version"

Gem::Specification.new do |spec|
  spec.name        = "action_push_native"
  spec.version     = ActionPushNative::VERSION
  spec.authors = [ "Jacopo Beschi" ]
  spec.email = [ "jacopo@37signals.com" ]

  spec.summary = "Send push notifications to mobile apps"
  spec.description = "Send push notifications to mobile apps"
  spec.homepage = "https://github.com/basecamp/action_push_native"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.post_install_message = <<-MESSAGE

    DEPRECATION WARNING:
  ! The "action_native_push" gem has been renamed to "action_push_native".
  ! See: https://rubygems.org/gems/action_push_native
  ! And: https://github.com/rails/action_push_native

  MESSAGE

  spec.required_ruby_version = '>= 3.2.0'

  rails_version = ">= 8.0"
  spec.add_dependency "activerecord", rails_version
  spec.add_dependency "activejob", rails_version
  spec.add_dependency "railties", rails_version
  spec.add_dependency "apnotic", "~> 1.7"
  spec.add_dependency "googleauth", "~> 1.14"
  spec.add_dependency "net-http", "~> 0.6"
end
