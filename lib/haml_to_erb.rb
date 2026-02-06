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
  # Holds conversion output and any validation errors.
  #
  # @example
  #   result = HamlToErb.convert_and_validate(haml_string)
  #   result.erb    #=> "<div class=\"foo\">...</div>"
  #   result.valid? #=> true
  #   result.errors #=> []
  class ValidationResult
    # @return [String] the converted ERB output
    attr_reader :erb
    # @return [Array<Hash>] validation errors, each with :message and optional :line, :column
    attr_reader :errors

    # @param erb [String] converted ERB string
    # @param errors [Array<Hash>] validation errors
    def initialize(erb:, errors: [])
      @erb = erb
      @errors = errors
    end

    # @return [Boolean] true when there are no validation errors
    def valid?
      @errors.empty?
    end

    # @return [Hash{Symbol => Object}] hash with :erb, :valid, and :errors keys
    def to_h
      { erb: @erb, valid: valid?, errors: @errors }
    end
  end

  # Convert a HAML string to ERB.
  #
  # @param input [String] HAML template source
  # @return [String] converted ERB output
  # @raise [Haml::SyntaxError] if the input is not valid HAML
  def self.convert(input)
    Converter.new(input).convert
  end

  # Validate ERB output using the Herb parser.
  #
  # @param erb [String] ERB string to validate
  # @return [ValidationResult]
  # @raise [RuntimeError] if the herb gem is not installed
  def self.validate(erb)
    require_herb!
    result = Herb.parse(erb)
    errors = result.success? ? [] : result.errors.map { |e| format_herb_error(e) }
    ValidationResult.new(erb: erb, errors: errors)
  end

  # Convert HAML to ERB and validate the output in one step.
  #
  # @param input [String] HAML template source
  # @return [ValidationResult]
  # @raise [RuntimeError] if the herb gem is not installed
  def self.convert_and_validate(input)
    erb = convert(input)
    validate(erb)
  end

  # Convert a single HAML file to ERB, writing the result alongside the original.
  #
  # @param haml_path [String] path to the .haml file
  # @param delete_original [Boolean] remove the .haml file after successful conversion
  # @param validate [Boolean] validate the ERB output with Herb
  # @param dry_run [Boolean] return the converted output without writing to disk
  # @return [Hash] result with :path, :errors, and optionally :skipped, :dry_run, :content
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
      line = e.respond_to?(:line) ? e.line : nil
      return { path: erb_path, errors: [ { message: "HAML syntax error: #{e.message}", line: line } ], skipped: true }
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

  # Convert all .haml files in a directory tree to ERB.
  #
  # @param dir_path [String] root directory to search for .haml files
  # @param delete_originals [Boolean] remove .haml files after successful conversion
  # @param validate [Boolean] validate each ERB output with Herb
  # @param dry_run [Boolean] return converted output without writing to disk
  # @return [Array<Hash>] array of result hashes, one per file (see {.convert_file})
  def self.convert_directory(dir_path, delete_originals: false, validate: false, dry_run: false)
    Dir.glob(File.join(dir_path, "**/*.haml")).map do |haml_path|
      convert_file(haml_path, delete_original: delete_originals, validate: validate, dry_run: dry_run)
    end
  end

  # Check if the Herb gem is available for validation.
  #
  # @return [Boolean]
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
