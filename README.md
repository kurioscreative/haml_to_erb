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

# Convert a single file
haml_to_erb file.html.haml

# Validate output with Herb
haml_to_erb app/views --check

# Preview without writing files
haml_to_erb app/views --dry-run

# Delete originals after conversion
haml_to_erb app/views --delete

# Skip confirmation prompts
haml_to_erb app/views --delete --force

# Show full backtraces on errors
haml_to_erb app/views --debug
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

## Design Decisions

### Static Value Optimization

The converter uses Ruby's Prism parser to detect static attribute values (strings, symbols, numbers, booleans) and inline them directly into HTML. Dynamic expressions fall back to ERB tags.

```haml
%div{ class: "foo", data: { action: "click" }, href: @path }
```

Becomes:

```erb
<div class="foo" data-action="click" href="<%= @path %>">
```

Without this optimization, all values would be wrapped in ERB:

```erb
<div class="<%= "foo" %>" data-action="<%= "click" %>" href="<%= @path %>">
```

This produces output that looks like what a human would write, making converted templates easier to review and maintain. It also avoids unnecessary ERB evaluation at runtime for values that never change.

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
