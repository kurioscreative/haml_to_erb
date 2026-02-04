# frozen_string_literal: true

require "json"
require_relative "prism_parser"
require_relative "interpolation"

module HamlToErb
  # Builds HTML attribute strings from HAML static and dynamic attributes
  # Single class consolidating parsing, building, and formatting
  class AttributeBuilder
    # HTML5 boolean attributes - presence matters, not value
    BOOLEAN_ATTRIBUTES = %w[
      allowfullscreen async autofocus autoplay checked controls default
      defer disabled formnovalidate hidden inert ismap itemscope loop
      multiple muted nomodule novalidate open playsinline readonly
      required reversed scoped seamless selected
    ].freeze

    def initialize
      @parser = PrismParser.new
    end

    # Build a complete HTML attribute string from static and dynamic HAML attributes
    # Returns a string like ' class="foo bar" id="main" href="/path"'
    # obj_ref_attrs: optional hash with class/id from object reference syntax
    def build(static, dynamic, obj_ref_attrs = nil)
      attrs = {}
      class_parts = []
      id_parts = []

      # Static attributes (already parsed by HAML - includes shorthand classes/ids)
      static&.each do |key, value|
        if key == "class"
          class_parts << value
        elsif key == "id"
          id_parts << value
        else
          attrs[key] = "#{key}=\"#{escape_attr(value)}\""
        end
      end

      # Dynamic attributes - parse the Ruby hash and convert to HTML
      if dynamic
        dyn = dynamic.old || dynamic.new
        if dyn && !dyn.empty?
          parse_dynamic(dyn).each do |attr_str|
            if attr_str.start_with?("class=")
              class_parts << extract_quoted_value(attr_str, "class")
            elsif attr_str.start_with?("id=")
              id_parts << extract_quoted_value(attr_str, "id")
            else
              attr_name = attr_str.split("=").first
              attrs[attr_name] = attr_str
            end
          end
        end
      end

      # Object reference attributes (from %div[@user] syntax)
      if obj_ref_attrs
        class_parts << obj_ref_attrs[:class] if obj_ref_attrs[:class]
        id_parts << obj_ref_attrs[:id] if obj_ref_attrs[:id]
      end

      # Build final parts array - escape non-ERB parts only
      parts = []
      parts << "class=\"#{escape_parts(class_parts).join(' ')}\"" if class_parts.any?
      parts << "id=\"#{escape_parts(id_parts).join(' ')}\"" if id_parts.any?
      parts.concat(attrs.values)

      parts.empty? ? "" : " " + parts.join(" ")
    end

    private

    def extract_quoted_value(attr_str, prefix)
      if attr_str =~ /\A#{prefix}="(.*)"\z/
        $1
      else
        attr_str.sub(/\A#{prefix}="/, "").sub(/"\z/, "")
      end
    end

    def parse_dynamic(hash_str)
      content = hash_str.strip
      content = content[1..-2] if content.start_with?("{") && content.end_with?("}")

      # Try to parse as static Ruby hash using Prism
      hash = @parser.parse_hash(content)
      return format_hash(hash) if hash

      # Fallback: parse key-value pairs and wrap dynamic values in ERB
      parse_to_erb_attrs(content)
    end

    # Convert a Ruby hash to an array of HTML attribute strings
    def format_hash(hash, prefix = nil)
      hash.flat_map do |key, value|
        attr_name = [ prefix, key.to_s.tr("_", "-") ].compact.join("-")
        format_attribute(attr_name, value)
      end
    end

    def format_attribute(attr_name, value)
      case value
      when Hash
        format_hash(value, attr_name)
      when true
        format_true_value(attr_name)
      when false
        format_false_value(attr_name)
      when nil
        []
      when Array
        format_array_value(attr_name, value)
      else
        [ "#{attr_name}=\"#{escape_attr(value.to_s)}\"" ]
      end
    end

    def format_true_value(attr_name)
      if attr_name.start_with?("aria-", "data-")
        [ "#{attr_name}=\"true\"" ]
      else
        [ attr_name ]
      end
    end

    def format_false_value(attr_name)
      if BOOLEAN_ATTRIBUTES.include?(attr_name)
        []
      else
        [ "#{attr_name}=\"false\"" ]
      end
    end

    def format_array_value(attr_name, value)
      if attr_name == "class"
        [ "#{attr_name}=\"#{escape_attr(value.join(' '))}\"" ]
      else
        [ "#{attr_name}=\"#{escape_attr(value.to_json)}\"" ]
      end
    end

    def parse_to_erb_attrs(hash_str)
      attrs = []
      remaining = hash_str.strip

      while remaining && !remaining.empty?
        # Skip double splat operator (**)
        if remaining.match?(/\A\s*\*\*/)
          warn "WARNING: Double splat (**) not supported in HAML attributes. " \
               "This attribute will be skipped. Consider rewriting without **."
          remaining = remaining.sub(/\A\s*\*\*/, "")
          _, remaining = extract_value(remaining)
          remaining = remaining&.sub(/\A\s*,\s*/, "")
          next
        end

        # Match key: symbol (:foo), string ('foo'/"foo"), or bare word (foo)
        match = remaining.match(/\A\s*(?::(\w+)|(['"])([\w-]+)\2|([\w-]+))\s*(?:=>|:)\s*/)
        break unless match

        key = (match[1] || match[3] || match[4]).tr("_", "-")
        remaining = remaining[match.end(0)..]

        value, remaining = extract_value(remaining)
        next if value.nil?

        attr = format_dynamic_value(key, value.strip)
        attrs << attr if attr

        remaining = remaining&.sub(/\A\s*,\s*/, "")
      end

      attrs
    end

    def extract_value(str)
      return [ nil, str ] if str.nil? || str.empty?

      depth = { "{" => 0, "(" => 0, "[" => 0 }
      close = { "{" => "}", "(" => ")", "[" => "]" }
      in_string = nil
      interpolation_depth = 0
      escape = false
      i = 0

      while i < str.length
        char = str[i]

        if escape
          escape = false
        elsif char == "\\"
          escape = true
        elsif interpolation_depth > 0
          if char == "{"
            interpolation_depth += 1
          elsif char == "}"
            interpolation_depth -= 1
          elsif char == '"' || char == "'"
            quote = char
            i += 1
            while i < str.length
              if str[i] == "\\"
                i += 2
              elsif str[i] == quote
                break
              else
                i += 1
              end
            end
          end
        elsif in_string
          if in_string == '"' && char == "#" && str[i + 1] == "{"
            interpolation_depth = 1
            i += 1
          elsif char == in_string
            in_string = nil
          end
        elsif char == '"' || char == "'"
          in_string = char
        elsif depth.key?(char)
          depth[char] += 1
        elsif close.values.include?(char)
          depth[close.key(char)] -= 1
        elsif char == "," && depth.values.all?(&:zero?)
          return [ str[0...i], str[i..] ]
        end

        i += 1
      end

      [ str, "" ]
    end

    def format_dynamic_value(key, value)
      if value.start_with?("{")
        format_nested_hash(key, value)
      elsif value.start_with?("[")
        format_array_literal(key, value)
      elsif value =~ /\A(["'])(.*)\1\z/m
        format_string_literal(key, value, $2)
      elsif value == "true"
        format_true_value(key).first || key
      elsif value == "false"
        format_false_literal(key)
      elsif value == "nil"
        nil
      elsif value =~ /\A:(\w+)\z/
        "#{key}=\"#{$1}\""
      elsif value =~ /\A\d+(\.\d+)?\z/
        "#{key}=\"#{value}\""
      elsif BOOLEAN_ATTRIBUTES.include?(key)
        "<%= '#{key}' if (#{value}) %>"
      else
        "#{key}=\"<%= #{value} %>\""
      end
    end

    def format_nested_hash(key, value)
      nested = @parser.parse_hash(value)
      if nested
        format_hash(nested, key).join(" ")
      else
        expand_nested_hash(key, value)
      end
    end

    def expand_nested_hash(prefix, hash_str)
      content = hash_str.strip
      content = content[1..-2] if content.start_with?("{") && content.end_with?("}")

      attrs = []
      remaining = content.strip

      while remaining && !remaining.empty?
        match = remaining.match(/\A\s*(?::(\w+)|(['"])([\w-]+)\2|([\w-]+))\s*(?:=>|:)\s*/)
        break unless match

        raw_key = (match[1] || match[3] || match[4]).tr("_", "-")
        attr_name = "#{prefix}-#{raw_key}"
        remaining = remaining[match.end(0)..]

        val, remaining = extract_value(remaining)
        next if val.nil?

        attr = format_dynamic_value(attr_name, val.strip)
        attrs << attr if attr

        remaining = remaining&.sub(/\A\s*,\s*/, "")
      end

      attrs.join(" ")
    end

    def format_array_literal(key, value)
      arr = @parser.parse_array(value)
      if arr
        json = key == "class" ? arr.join(" ") : arr.to_json
        "#{key}=\"#{escape_attr(json)}\""
      else
        "#{key}=\"<%= #{value} %>\""
      end
    end

    def format_string_literal(key, value, inner)
      if inner.match?(/['"]\s*\+|\+\s*['"]/)
        "#{key}=\"<%= #{value} %>\""
      elsif inner.include?('#{')
        "#{key}=\"#{Interpolation.convert(inner)}\""
      else
        "#{key}=\"#{inner}\""
      end
    end

    def format_false_literal(key)
      if BOOLEAN_ATTRIBUTES.include?(key)
        nil
      else
        "#{key}=\"false\""
      end
    end

    # Escape an array of attribute parts, skipping ERB expressions
    def escape_parts(parts)
      parts.map { |part| part.include?("<%") ? part : escape_attr(part) }
    end

    # HTML5 attribute escaping:
    # - & → &amp; (prevents entity injection)
    # - " → &quot; (prevents attribute boundary escape)
    # - < and > NOT escaped (valid in HTML5 attribute values per spec,
    #   required for Stimulus actions like "click->form#submit")
    def escape_attr(str)
      str.to_s.gsub("&", "&amp;").gsub('"', "&quot;")
    end
  end
end
