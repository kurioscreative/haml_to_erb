# frozen_string_literal: true

require "spec_helper"

RSpec.describe HamlToErb::Interpolation do
  describe ".convert" do
    context "simple interpolation" do
      it 'converts #{expr} to <%= expr %>' do
        expect(described_class.convert('Hello #{name}')).to eq("Hello <%= name %>")
      end

      it "handles interpolation at string start" do
        expect(described_class.convert('#{greeting} world')).to eq("<%= greeting %> world")
      end

      it "handles interpolation at string end" do
        expect(described_class.convert('Hello #{name}')).to eq("Hello <%= name %>")
      end

      it "returns string unchanged when no interpolation" do
        expect(described_class.convert("Hello world")).to eq("Hello world")
      end

      it "returns empty string unchanged" do
        expect(described_class.convert("")).to eq("")
      end
    end

    context "multiple interpolations" do
      it "converts multiple interpolations in one string" do
        result = described_class.convert('Hello #{first} #{last}')
        expect(result).to eq("Hello <%= first %> <%= last %>")
      end

      it "handles adjacent interpolations" do
        result = described_class.convert('#{a}#{b}#{c}')
        expect(result).to eq("<%= a %><%= b %><%= c %>")
      end
    end

    context "nested braces" do
      it "handles hash access" do
        result = described_class.convert('Value: #{hash[:key]}')
        expect(result).to eq("Value: <%= hash[:key] %>")
      end

      it "handles nested hash access" do
        result = described_class.convert('Value: #{hash[:outer][:inner]}')
        expect(result).to eq("Value: <%= hash[:outer][:inner] %>")
      end

      it "handles blocks with braces" do
        result = described_class.convert('Total: #{items.sum { |i| i.price }}')
        expect(result).to eq("Total: <%= items.sum { |i| i.price } %>")
      end

      it "handles string literals with braces inside interpolation" do
        result = described_class.convert('Value: #{"hello {world}"}')
        expect(result).to eq('Value: <%= "hello {world}" %>')
      end

      it "handles method calls with hash arguments" do
        result = described_class.convert('#{link_to "Home", path, class: "btn"}')
        expect(result).to eq('<%= link_to "Home", path, class: "btn" %>')
      end
    end

    context "escaped interpolation" do
      it 'preserves \\#{expr} as literal #{expr}' do
        result = described_class.convert('Hello \#{name}')
        expect(result).to eq('Hello #{name}')
        expect(result).not_to include("<%=")
      end

      it 'converts \\\\#{expr} to \\<%= expr %>' do
        result = described_class.convert('Path: \\\\#{value}')
        expect(result).to include("\\<%= value %>")
      end

      it "handles mixed escaped and unescaped interpolations" do
        result = described_class.convert('#{real} and \#{literal}')
        expect(result).to include("<%= real %>")
        expect(result).to include('#{literal}')
        expect(result).not_to include("<%= literal %>")
      end

      it "handles multiple escaped interpolations" do
        result = described_class.convert('\\#{a} and \\#{b}')
        expect(result).to eq('#{a} and #{b}')
      end

      it "handles escaped at string end" do
        result = described_class.convert('text \\#{expr}')
        expect(result).to eq('text #{expr}')
      end
    end

    context "edge cases" do
      it "handles interpolation with only expression" do
        result = described_class.convert('#{expr}')
        expect(result).to eq("<%= expr %>")
      end

      it "handles strings with # but not interpolation" do
        expect(described_class.convert("Price: $100")).to eq("Price: $100")
        expect(described_class.convert("# Comment")).to eq("# Comment")
      end

      it "handles nested strings in interpolation" do
        result = described_class.convert('#{user["name"]}')
        expect(result).to eq('<%= user["name"] %>')
      end

      it "handles single quotes in interpolation" do
        result = described_class.convert("\#{user['name']}")
        expect(result).to eq("<%= user['name'] %>")
      end

      it "handles escaped backslash before closing quote" do
        result = described_class.convert('Path: #{"C:\\\\"}')
        expect(result).to eq('Path: <%= "C:\\\\" %>')
      end
    end

    context "unclosed interpolation" do
      it "raises on unclosed interpolation" do
        expect { described_class.convert('Hello #{name') }
          .to raise_error(ArgumentError, /Unclosed interpolation/)
      end

      it "raises on unclosed with nested braces" do
        expect { described_class.convert('#{hash[:key]') }
          .to raise_error(ArgumentError, /Unclosed interpolation/)
      end
    end
  end
end
