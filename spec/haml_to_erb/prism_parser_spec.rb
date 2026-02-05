# frozen_string_literal: true

require "spec_helper"

RSpec.describe HamlToErb::PrismParser do
  let(:parser) { described_class.new }

  describe "#parse_hash" do
    context "static hashes" do
      it "parses simple symbol-keyed hash" do
        result = parser.parse_hash("{ a: 1, b: 2 }")
        expect(result).to eq({ a: 1, b: 2 })
      end

      it "parses hash with string values" do
        result = parser.parse_hash('{ name: "Alice", city: "NYC" }')
        expect(result).to eq({ name: "Alice", city: "NYC" })
      end

      it "parses hash with mixed value types" do
        result = parser.parse_hash('{ count: 42, rate: 3.14, active: true, deleted: false }')
        expect(result).to eq({ count: 42, rate: 3.14, active: true, deleted: false })
      end

      # NOTE: PrismParser returns nil for hashes containing nil values
      # because nil values are typically omitted in HTML attributes
      it "returns nil for hash with nil values (treated as dynamic)" do
        result = parser.parse_hash("{ value: nil }")
        expect(result).to be_nil
      end

      it "parses hash with symbol values" do
        result = parser.parse_hash("{ type: :admin }")
        expect(result).to eq({ type: :admin })
      end

      it "parses hash without braces" do
        result = parser.parse_hash('name: "test", count: 5')
        expect(result).to eq({ name: "test", count: 5 })
      end

      it "parses empty hash" do
        result = parser.parse_hash("{}")
        expect(result).to eq({})
      end
    end

    context "nested hashes" do
      it "parses nested hash" do
        result = parser.parse_hash("{ data: { x: 1, y: 2 } }")
        expect(result).to eq({ data: { x: 1, y: 2 } })
      end

      it "parses deeply nested hash" do
        result = parser.parse_hash("{ outer: { middle: { inner: 1 } } }")
        expect(result).to eq({ outer: { middle: { inner: 1 } } })
      end
    end

    context "string keys" do
      it "parses hash with string keys" do
        result = parser.parse_hash('{ "aria-label" => "Close" }')
        expect(result).to eq({ "aria-label" => "Close" })
      end

      it "parses mixed symbol and string keys" do
        result = parser.parse_hash('{ name: "test", "data-value" => 42 }')
        expect(result).to eq({ name: "test", "data-value" => 42 })
      end
    end

    context "dynamic values (returns nil)" do
      it "returns nil for method calls" do
        expect(parser.parse_hash("{ value: some_method }")).to be_nil
      end

      it "returns nil for variable references" do
        expect(parser.parse_hash("{ value: my_var }")).to be_nil
      end

      it "returns nil for instance variables" do
        expect(parser.parse_hash("{ value: @user }")).to be_nil
      end

      it "returns nil for interpolated strings" do
        expect(parser.parse_hash('{ value: "hello #{name}" }')).to be_nil
      end

      it "returns nil for method calls with arguments" do
        expect(parser.parse_hash("{ url: url_for(@item) }")).to be_nil
      end

      it "returns nil for ternary operators" do
        expect(parser.parse_hash('{ class: active? ? "on" : "off" }')).to be_nil
      end
    end

    context "splat operators (returns nil)" do
      it "returns nil for double splat" do
        expect(parser.parse_hash("{ **options }")).to be_nil
      end

      it "returns nil for hash with double splat" do
        expect(parser.parse_hash("{ a: 1, **extra }")).to be_nil
      end
    end

    context "syntax errors (returns nil)" do
      it "returns nil for invalid syntax" do
        expect(parser.parse_hash("{ a: }")).to be_nil
      end

      it "returns nil for unclosed brace" do
        expect(parser.parse_hash("{ a: 1")).to be_nil
      end
    end
  end

  describe "#parse_array" do
    context "static arrays" do
      it "parses simple array" do
        result = parser.parse_array("[1, 2, 3]")
        expect(result).to eq([1, 2, 3])
      end

      it "parses array of strings" do
        result = parser.parse_array('["foo", "bar", "baz"]')
        expect(result).to eq(%w[foo bar baz])
      end

      it "parses array of symbols" do
        result = parser.parse_array("[:a, :b, :c]")
        expect(result).to eq(%i[a b c])
      end

      it "parses mixed type array" do
        result = parser.parse_array('[1, "two", :three, true]')
        expect(result).to eq([1, "two", :three, true])
      end

      it "parses empty array" do
        result = parser.parse_array("[]")
        expect(result).to eq([])
      end

      it "parses nested arrays" do
        result = parser.parse_array("[[1, 2], [3, 4]]")
        expect(result).to eq([[1, 2], [3, 4]])
      end
    end

    context "dynamic values (returns nil)" do
      it "returns nil for method calls in array" do
        expect(parser.parse_array("[some_method]")).to be_nil
      end

      it "returns nil for variables in array" do
        expect(parser.parse_array("[my_var, 1, 2]")).to be_nil
      end

      it "returns nil for interpolated strings" do
        expect(parser.parse_array('["hello #{name}"]')).to be_nil
      end
    end

    context "syntax errors (returns nil)" do
      it "returns nil for unclosed bracket" do
        expect(parser.parse_array("[1, 2")).to be_nil
      end

      it "returns nil for truly invalid syntax" do
        expect(parser.parse_array("[1 2]")).to be_nil
      end
    end

    context "trailing commas (valid Ruby)" do
      it "allows trailing comma in array" do
        result = parser.parse_array("[1, 2,]")
        expect(result).to eq([1, 2])
      end
    end
  end
end
