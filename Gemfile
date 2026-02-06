# frozen_string_literal: true

source "https://rubygems.org"

gemspec

# Allow CI to override haml version for compatibility testing
gem "haml", ENV["HAML_VERSION"] if ENV["HAML_VERSION"]

group :development, :test do
  gem "herb"
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-rspec"
end
