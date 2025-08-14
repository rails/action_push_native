# frozen_string_literal: true

require_relative "lib/action_native_push/version"

Gem::Specification.new do |spec|
  spec.name        = "action_native_push"
  spec.version     = ActionNativePush::VERSION
  spec.authors = [ "Jacopo Beschi" ]
  spec.email = [ "jacopo@37signals.com" ]

  spec.summary = "Send push notifications to mobile apps"
  spec.description = "Send push notifications to mobile apps"
  spec.homepage = "https://github.com/basecamp/action_native_push"
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
  spec.add_dependency "apnotic", "~> 1.7"
  spec.add_dependency "googleauth", "~> 1.14"
  spec.add_dependency "net-http", "~> 0.6"
end
