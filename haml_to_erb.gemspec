# frozen_string_literal: true

require_relative "lib/haml_to_erb/version"

Gem::Specification.new do |spec|
  spec.name = "haml_to_erb"
  spec.version = HamlToErb::VERSION
  spec.authors = [ "Glenn Ericksen" ]
  spec.email = [ "glenn.m.ericksen@gmail.com" ]

  spec.summary = "Convert HAML templates to ERB"
  spec.description = "A HAML to ERB converter for migrating Rails views. " \
                     "Handles tags, attributes, Ruby code, blocks, filters, and interpolation."
  spec.homepage = "https://github.com/kurioscreative/haml_to_erb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = [ "haml_to_erb" ]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "haml", ">= 5.0", "< 8"
  spec.add_dependency "prism", ">= 0.24", "< 2"

  spec.add_development_dependency "herb", "~> 0.8"
end
