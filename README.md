# HamlToErb

Converts HAML templates to ERB format.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'haml_to_erb'
```

Or install directly:

```bash
gem install haml_to_erb
```

## Usage

### Convert a string

```ruby
erb = HamlToErb.convert(haml_string)
```

### Convert a file

```ruby
result = HamlToErb.convert_file("app/views/home.html.haml")
# => { path: "app/views/home.html.erb", errors: [] }

# With validation
result = HamlToErb.convert_file(path, validate: true)

# Delete original after conversion
result = HamlToErb.convert_file(path, delete_original: true)

# Dry run (preview without writing)
result = HamlToErb.convert_file(path, dry_run: true)
# => { path: "...", errors: [], dry_run: true, content: "<erb output>" }
```

### Convert a directory

```ruby
results = HamlToErb.convert_directory("app/views")
# => [{ path: "...", errors: [] }, ...]

results = HamlToErb.convert_directory("app/views",
  delete_originals: true,  # Remove .haml files
  validate: true,          # Validate ERB output
  dry_run: true            # Preview only
)
```

### Command Line

```bash
# Convert all HAML files in directory
haml_to_erb app/views

# Convert and validate with Herb
haml_to_erb app/views --check

# Convert a single file
haml_to_erb file.html.haml

# Delete originals after conversion
haml_to_erb app/views --delete
```

## Error Handling

File operations return error details without raising exceptions:

```ruby
result = HamlToErb.convert_file("nonexistent.haml")
# => { path: "nonexistent.erb", errors: [{ message: "File not found: nonexistent.haml" }], skipped: true }

# Permission errors
# => { ..., errors: [{ message: "Permission denied: ..." }], skipped: true }

# HAML syntax errors
# => { ..., errors: [{ message: "HAML syntax error: ...", line: 5 }], skipped: true }
```

## Known Limitations

- Double splat (`**`) in attributes not supported (warning issued)
- Whitespace removal markers (`>`, `<`) parsed but whitespace not removed
- Old doctypes (`!!! Strict`, `!!! Transitional`) converted to HTML5
- `:markdown` and other custom filters output as HTML comments

## Validation

Requires the `herb` gem for ERB validation:

```ruby
gem 'herb'
```

```ruby
result = HamlToErb.validate(erb_string)
result.valid?  # => true/false
result.errors  # => [{ message:, line:, column: }, ...]

# Or combine conversion + validation
result = HamlToErb.convert_and_validate(haml_string)
result.erb     # => "<converted erb>"
result.valid?  # => true/false
```

## License

The gem is available as open source under the terms of the MIT License.
