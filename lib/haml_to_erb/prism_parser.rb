# frozen_string_literal: true

require "prism"

module HamlToErb
  # Safely parses Ruby hash and array literals using Prism AST
  # Returns nil if the expression contains dynamic values (method calls, variables)
  class PrismParser
    # Parse a Ruby hash literal string, returning a Ruby Hash if all values are static
    # Returns nil if parsing fails or the hash contains dynamic expressions
    def parse_hash(str)
      content = str.strip
      content = "{#{content}}" unless content.start_with?("{")

      result = Prism.parse(content)
      return nil if result.errors.any?

      statements = result.value.statements.body
      return nil unless statements.length == 1

      extract_value(statements.first)
    end

    # Parse a Ruby array literal string
    def parse_array(str)
      result = Prism.parse(str.strip)
      return nil if result.errors.any?

      statements = result.value.statements.body
      return nil unless statements.length == 1

      extract_value(statements.first)
    end

    private

    # rubocop:disable Lint/DuplicateBranch, Style/EmptyElse
    def extract_value(node)
      case node
      when Prism::HashNode then extract_hash(node)
      when Prism::ArrayNode then extract_array(node)
      when Prism::StringNode then node.unescaped
      when Prism::SymbolNode then node.unescaped.to_sym
      when Prism::IntegerNode then node.value
      when Prism::FloatNode then node.value
      when Prism::TrueNode then true
      when Prism::FalseNode then false
      when Prism::NilNode then nil
      when Prism::InterpolatedStringNode then nil # dynamic
      else nil # method calls, variables, etc.
      end
    end
    # rubocop:enable Lint/DuplicateBranch, Style/EmptyElse

    # rubocop:disable Lint/DuplicateBranch
    def extract_hash(node)
      result = {}
      node.elements.each do |element|
        case element
        when Prism::AssocNode
          key = extract_key(element.key)
          return nil if key.nil?

          value = extract_value(element.value)
          return nil if value.nil?

          result[key] = value
        when Prism::AssocSplatNode
          return nil # **hash - dynamic
        else
          return nil
        end
      end
      result
    end
    # rubocop:enable Lint/DuplicateBranch

    def extract_array(node)
      result = []
      node.elements.each do |element|
        value = extract_value(element)
        return nil if value.nil?

        result << value
      end
      result
    end

    # rubocop:disable Style/EmptyElse
    def extract_key(node)
      case node
      when Prism::SymbolNode then node.unescaped.to_sym
      when Prism::StringNode then node.unescaped
      else nil
      end
    end
    # rubocop:enable Style/EmptyElse
  end
end
