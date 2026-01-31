# frozen_string_literal: true

require_relative "lib/haml_to_erb/version"

Gem::Specification.new do |spec|
  spec.name = "haml_to_erb"
  spec.version = HamlToErb::VERSION
  spec.authors = ["Glenn Ericksen"]
  spec.email = ["glenn.m.ericksen@gmail.com"]

  spec.summary = "Convert HAML templates to ERB"
  spec.description = "A HAML to ERB converter for migrating Rails views. Handles tags, attributes, Ruby code, blocks, filters, and interpolation."
  spec.homepage = "https://github.com/kurioscreative/haml_to_erb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,exe}/**/*", "README.md", "LICENSE.txt"].reject { |f| File.directory?(f) }
  end
  spec.bindir = "exe"
  spec.executables = ["haml_to_erb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "haml", ">= 6.0"
  spec.add_dependency "prism", ">= 0.24"

  spec.add_development_dependency "herb", ">= 0.1"
  spec.add_development_dependency "rspec", "~> 3.0"
end
