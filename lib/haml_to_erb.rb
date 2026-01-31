# frozen_string_literal: true

require_relative "haml_to_erb/version"
require_relative "haml_to_erb/converter"

# HamlToErb - A HAML to ERB converter
#
# Converts HAML templates to ERB format. Designed for migration tools
# running on trusted source files.
#
# Features:
# - Tags with classes/IDs: %div.class#id
# - Ruby hash attributes: { key: 'value', data: { x: 1 } }
# - HTML attributes: (href="url")
# - Ruby code: = output, - silent
# - Blocks with do |var|
# - Filters: :javascript, :plain, :css, :erb
# - Interpolation: #{expression}
#
# Usage:
#   HamlToErb.convert(haml_string)  # Returns ERB string
#   HamlToErb.convert_file('path/to/file.haml')  # Creates .erb file
#   HamlToErb.convert_directory('app/views')  # Converts all .haml files
#
# Validation (requires herb gem):
#   HamlToErb.validate(erb_string)  # Returns { valid: bool, errors: [...] }
#   HamlToErb.convert_and_validate(haml_string)  # Returns { erb:, valid:, errors: }
#
module HamlToErb
  class ValidationResult
    attr_reader :erb, :errors

    def initialize(erb:, errors: [])
      @erb = erb
      @errors = errors
    end

    def valid?
      @errors.empty?
    end

    def to_h
      { erb: @erb, valid: valid?, errors: @errors }
    end
  end

  def self.convert(input)
    Converter.new(input).convert
  end

  # Validate ERB using Herb parser
  # Returns ValidationResult with errors array
  def self.validate(erb)
    require_herb!
    result = Herb.parse(erb)
    errors = result.success? ? [] : result.errors.map { |e| format_herb_error(e) }
    ValidationResult.new(erb: erb, errors: errors)
  end

  # Convert HAML to ERB and validate the output
  # Returns ValidationResult
  def self.convert_and_validate(input)
    erb = convert(input)
    validate(erb)
  end

  def self.convert_file(haml_path, delete_original: false, validate: false, dry_run: false)
    erb_path = haml_path.sub(/\.haml\z/, ".erb")

    begin
      content = File.read(haml_path)
      erb = convert(content)
    rescue Errno::ENOENT
      return { path: erb_path, errors: [ { message: "File not found: #{haml_path}" } ], skipped: true }
    rescue Errno::EACCES
      return { path: erb_path, errors: [ { message: "Permission denied: #{haml_path}" } ], skipped: true }
    rescue Haml::SyntaxError => e
      return { path: erb_path, errors: [ { message: "HAML syntax error: #{e.message}", line: e.line } ], skipped: true }
    end

    unless dry_run
      begin
        File.write(erb_path, erb)
        File.delete(haml_path) if delete_original
      rescue Errno::EACCES
        return { path: erb_path, errors: [ { message: "Cannot write: #{erb_path}" } ], skipped: true }
      end
    end

    errors = validate ? self.validate(erb).errors : []
    result = { path: erb_path, errors: errors }
    result[:dry_run] = true if dry_run
    result[:content] = erb if dry_run
    result
  end

  def self.convert_directory(dir_path, delete_originals: false, validate: false, dry_run: false)
    Dir.glob(File.join(dir_path, "**/*.haml")).map do |haml_path|
      convert_file(haml_path, delete_original: delete_originals, validate: validate, dry_run: dry_run)
    end
  end

  # Check if Herb gem is available
  def self.herb_available?
    require "herb"
    true
  rescue LoadError
    false
  end

  private_class_method def self.require_herb!
    require "herb"
  rescue LoadError
    raise "Herb gem is required for validation. Install with: gem install herb"
  end

  private_class_method def self.format_herb_error(error)
    {
      message: error.message,
      line: error.respond_to?(:line) ? error.line : nil,
      column: error.respond_to?(:column) ? error.column : nil
    }
  end
end
