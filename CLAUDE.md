# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HamlToErb is a Ruby gem that converts HAML templates to ERB format. It uses the HAML parser to build an AST, then walks the tree to emit ERB output. Designed for migrating Rails views.

## Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/haml_to_erb_spec.rb

# Run specific test by line number
bundle exec rspec spec/haml_to_erb_spec.rb:105

# CLI usage
bundle exec exe/haml_to_erb app/views           # Convert directory
bundle exec exe/haml_to_erb file.html.haml      # Convert single file
bundle exec exe/haml_to_erb app/views --check   # Validate output with Herb
bundle exec exe/haml_to_erb app/views --delete  # Delete originals after conversion
```

## Architecture

The conversion pipeline: HAML string → Haml::Parser → AST → Converter → ERB string

**Core classes:**

- `Converter` (lib/haml_to_erb/converter.rb) - Main conversion logic. Walks AST via `emit()` method with case dispatch on node types (`:tag`, `:script`, `:silent_script`, `:filter`, etc.). Handles nesting, blocks, control flow, and filters.

- `AttributeBuilder` (lib/haml_to_erb/attribute_builder.rb) - Converts HAML attributes (both static and dynamic) to HTML attribute strings. Merges shorthand classes/IDs with hash attributes. Uses PrismParser for static values, falls back to ERB wrapping for dynamic expressions.

- `PrismParser` (lib/haml_to_erb/prism_parser.rb) - Uses Ruby's Prism parser to safely extract values from static hash/array literals. Returns nil for dynamic expressions (method calls, interpolation), signaling fallback to ERB output.

- `Interpolation` (lib/haml_to_erb/interpolation.rb) - Converts Ruby `#{expr}` interpolation to `<%= expr %>` ERB tags. Tracks brace depth for nested expressions.

**Key design decisions:**

- Static values are inlined; dynamic values become `<%= expr %>`
- Boolean HTML attributes (checked, disabled) output name only when true, omit when false
- ARIA/data attributes output `"true"`/`"false"` as string values
- Void elements (br, img, input) emit no closing tag; warns if HAML nests children under them

## Testing

Tests use RSpec with a custom `be_valid_erb` matcher that validates output against the Herb parser. The spec file is organized by feature area with extensive edge case coverage.

## Known Limitations

- Double splat (`**`) in attributes not supported (warning issued, attribute skipped)
- Whitespace removal markers (`>`, `<`) parsed but not applied
- Old doctypes converted to HTML5
- Unknown filters (`:markdown`, etc.) output as HTML comments
