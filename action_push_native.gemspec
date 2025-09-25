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

  spec.required_ruby_version = '>= 3.2.0'

  rails_version = ">= 8.0"
  spec.add_dependency "activerecord", rails_version
  spec.add_dependency "activejob", rails_version
  spec.add_dependency "railties", rails_version
  spec.add_dependency "httpx", "~> 1.6"
  spec.add_dependency "jwt", ">= 2"
  spec.add_dependency "googleauth", "~> 1.14"
end
