# frozen_string_literal: true

require "haml"
require_relative "attribute_builder"
require_relative "interpolation"

module HamlToErb
  # Converts HAML to ERB using the HAML parser
  # Single class handling all node types via case dispatch
  class Converter
    BLOCK_KEYWORDS = %w[if unless case begin while until for].freeze
    MID_BLOCK_KEYWORDS = %w[else elsif when rescue ensure].freeze
    VOID_ELEMENTS = %w[area base br col embed hr img input link meta param source track wbr].freeze

    def initialize(input)
      @input = input
      @attribute_builder = AttributeBuilder.new
    end

    def convert
      parser = Haml::Parser.new({})
      ast = parser.call(@input)
      emit(ast, 0)
    end

    private

    def emit(node, depth)
      case node.type
      when :root         then emit_children(node, depth)
      when :tag          then emit_tag(node, depth)
      when :script       then emit_script(node, depth)
      when :silent_script then emit_silent_script(node, depth)
      when :filter       then emit_filter(node, depth)
      when :doctype      then emit_doctype(node, depth)
      when :comment      then emit_comment(node, depth)
      when :plain        then emit_plain(node, depth)
      when :haml_comment then ""
      else
        warn "Unknown node type: #{node.type}"
        ""
      end
    end

    def emit_children(node, depth)
      node.children.map { |child| emit(child, depth) }.join
    end

    def emit_tag(node, depth)
      ind = indent(depth)
      v = node.value
      tag = v[:name]

      # Handle object reference syntax: %div[@user] or %div[@item, :prefix]
      obj_ref_attrs = build_object_ref_attrs(v[:object_ref])
      attrs = @attribute_builder.build(v[:attributes], v[:dynamic_attributes], obj_ref_attrs)
      is_void = VOID_ELEMENTS.include?(tag)

      result = "#{ind}<#{tag}#{attrs}>"

      if v[:self_closing] || (is_void && node.children.empty? && (v[:value].nil? || v[:value].to_s.empty?))
        result + "\n"
      elsif v[:value] && !v[:value].to_s.empty?
        content = format_tag_content(v)
        if is_void
          warn "WARNING: Void element <#{tag}> has inline content at line #{node.line}. " \
               "Content will be emitted as a sibling."
          "#{result}\n#{ind}#{content}\n"
        else
          "#{result}#{content}</#{tag}>\n"
        end
      elsif node.children.any?
        if is_void
          warn "WARNING: Void element <#{tag}> has nested children at line #{node.line}. " \
               "Children will be emitted as siblings. Consider restructuring your HAML."
          result + "\n" + emit_children(node, depth + 1)
        else
          result + "\n" + emit_children(node, depth + 1) + "#{ind}</#{tag}>\n"
        end
      else
        is_void ? result + "\n" : "#{result}</#{tag}>\n"
      end
    end

    def emit_script(node, depth)
      ind = indent(depth)
      code = node.value[:text].strip

      if node.children.any?
        "#{ind}<%= #{code} %>\n" + emit_children(node, depth + 1) + "#{ind}<% end %>\n"
      elsif code.start_with?('"') && code.end_with?('"') && code.include?('#{')
        # String literal with interpolation - convert to text + ERB
        # Only handles \" and \\. Complex escape sequences (\n, \t, \u{...}) are
        # passed through literally — a known limitation (see CLAUDE.md).
        inner = code[1..-2]
        unescaped = inner.gsub('\"', '"').gsub("\\\\", "\\")
        "#{ind}#{Interpolation.convert(unescaped)}\n"
      else
        "#{ind}<%= #{code} %>\n"
      end
    end

    def emit_silent_script(node, depth)
      ind = indent(depth)
      code = node.value[:text].strip
      keyword = node.value[:keyword]

      result = "#{ind}<% #{code} %>\n"

      # Process children - mid-block keywords (else/when) stay at same depth
      node.children.each do |child|
        child_depth = if child.type == :silent_script && MID_BLOCK_KEYWORDS.include?(child.value[:keyword])
          depth
        else
          depth + 1
        end
        result += emit(child, child_depth)
      end

      # Add end tag for block starters (not mid-block keywords)
      # HAML parser sets keyword for if/unless/case/begin but not while/until/for
      needs_end = BLOCK_KEYWORDS.include?(keyword) ||
                  code.match?(/\bdo\s*(\|[^|]*\|)?\s*\z/) ||
                  code.match?(/\A\s*(while|until|for)\b/)
      result += "#{ind}<% end %>\n" if needs_end && node.children.any?

      result
    end

    def emit_filter(node, depth)
      ind = indent(depth)
      name = node.value[:name]
      text = node.value[:text]

      case name
      when "javascript"
        "#{ind}<script>\n" + text.lines.map { |l|
          "#{ind}  #{Interpolation.convert(l.rstrip)}\n"
        }.join + "#{ind}</script>\n"
      when "css"
        "#{ind}<style>\n" + text.lines.map { |l|
          "#{ind}  #{Interpolation.convert(l.rstrip)}\n"
        }.join + "#{ind}</style>\n"
      when "plain", "erb"
        text.lines.map { |l| "#{ind}#{l.rstrip}\n" }.join
      when "ruby"
        text.lines.map { |l| "#{ind}<% #{l.strip} %>\n" }.join
      else
        "#{ind}<!-- Unknown filter: #{name} -->\n#{ind}#{text}\n"
      end
    end

    def emit_doctype(node, _depth)
      v = node.value
      if v[:type] == "xml"
        encoding = v[:encoding] || "UTF-8"
        "<?xml version=\"1.0\" encoding=\"#{encoding}\"?>\n"
      else
        "<!DOCTYPE html>\n"
      end
    end

    def emit_comment(node, depth)
      "#{indent(depth)}<!-- #{node.value[:text]} -->\n"
    end

    def emit_plain(node, depth)
      "#{indent(depth)}#{Interpolation.convert(node.value[:text])}\n"
    end

    def format_tag_content(tag_data)
      val = tag_data[:value].to_s
      if tag_data[:parse]
        if val.start_with?('"') && val.end_with?('"') && val.include?('#{')
          # Only handles \" and \\. Complex escape sequences (\n, \t, \u{...}) are
          # passed through literally — a known limitation (see CLAUDE.md).
          inner = val[1..-2]
          unescaped = inner.gsub('\"', '"').gsub("\\\\", "\\")
          Interpolation.convert(unescaped)
        else
          "<%= #{val} %>"
        end
      else
        Interpolation.convert(val)
      end
    end

    def indent(depth)
      "  " * depth
    end

    # Parse object reference syntax: %div[@user] or %div[@item, :prefix]
    # Returns hash with :class and :id ERB expressions, or nil if no object_ref
    def build_object_ref_attrs(object_ref)
      return nil if object_ref.nil?

      content = object_ref.to_s.strip
      return nil if content.empty?

      # Object reference must be in brackets: [@user] or [@item, :prefix]
      return nil unless content.start_with?("[") && content.end_with?("]")

      # Extract content from brackets
      content = content[1..-2].strip
      return nil if content.empty?

      # Split into object and optional prefix: @user or @item, :prefix
      parts = content.split(/,\s*/, 2)
      obj_var = parts[0].strip
      prefix = parts[1]&.strip

      # Build ERB expressions for class and id
      # class: model_name.element (e.g., "user")
      # id: model_name.element + "_" + to_key (e.g., "user_42")
      class_expr = "#{obj_var}.class.name.underscore"
      id_expr = "#{obj_var}.class.name.underscore + '_' + #{obj_var}.to_key.first.to_s"

      # Apply prefix if provided (e.g., :prefix -> "prefix_user", "prefix_user_42")
      if prefix
        # Strip leading colon from symbol prefix
        prefix_str = prefix.sub(/\A:/, "")
        class_expr = "\"#{prefix_str}_\" + #{class_expr}"
        id_expr = "\"#{prefix_str}_\" + #{id_expr}"
      end

      {
        class: "<%= #{class_expr} %>",
        id: "<%= #{id_expr} %>"
      }
    end
  end
end
