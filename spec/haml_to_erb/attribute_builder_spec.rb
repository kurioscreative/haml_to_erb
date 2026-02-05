# frozen_string_literal: true

require "spec_helper"

RSpec.describe HamlToErb::AttributeBuilder do
  let(:builder) { described_class.new }

  # Helper to build attrs from a dynamic hash string (simulates HAML parser output)
  def build_dynamic(hash_str)
    dynamic = Struct.new(:old, :new).new(hash_str, nil)
    builder.build(nil, dynamic, nil)
  end

  describe "#build" do
    context "with static attributes only" do
      it "formats simple static attributes" do
        result = builder.build({ "href" => "/path" }, nil, nil)
        expect(result).to eq(' href="/path"')
      end

      it "handles multiple static attributes" do
        result = builder.build({ "href" => "/path", "target" => "_blank" }, nil, nil)
        expect(result).to include('href="/path"')
        expect(result).to include('target="_blank"')
      end

      it "returns empty string for nil attributes" do
        result = builder.build(nil, nil, nil)
        expect(result).to eq("")
      end

      it "handles empty hash" do
        result = builder.build({}, nil, nil)
        expect(result).to eq("")
      end
    end

    context "class and ID merging" do
      it "combines static class values" do
        result = builder.build({ "class" => "foo bar" }, nil, nil)
        expect(result).to eq(' class="foo bar"')
      end

      it "merges shorthand classes with hash class" do
        static = { "class" => "page-nav" }
        dynamic = Struct.new(:old, :new).new('class: "navbar"', nil)
        result = builder.build(static, dynamic, nil)
        expect(result).to include('class="page-nav navbar"')
        expect(result.scan("class=").count).to eq(1)
      end

      it "merges multiple shorthand classes with hash class" do
        static = { "class" => "foo bar" }
        dynamic = Struct.new(:old, :new).new('class: "baz qux"', nil)
        result = builder.build(static, dynamic, nil)
        expect(result).to include('class="foo bar baz qux"')
      end

      it "merges shorthand ID with hash ID" do
        static = { "id" => "foo" }
        dynamic = Struct.new(:old, :new).new('id: "bar"', nil)
        result = builder.build(static, dynamic, nil)
        expect(result).to include('id="foo bar"')
        expect(result.scan("id=").count).to eq(1)
      end
    end

    context "object reference attributes" do
      it "adds class and ID from object reference" do
        obj_ref = { class: "<%= @user.class.name.underscore %>", id: "<%= @user.to_key %>" }
        result = builder.build(nil, nil, obj_ref)
        expect(result).to include("class=")
        expect(result).to include("id=")
      end
    end
  end

  describe "dynamic attribute parsing" do
    context "static values in dynamic hash" do
      it "parses string values" do
        result = build_dynamic('href: "/path"')
        expect(result).to eq(' href="/path"')
      end

      it "parses symbol values as strings" do
        result = build_dynamic("type: :text")
        expect(result).to eq(' type="text"')
      end

      it "parses numeric values" do
        result = build_dynamic("tabindex: 1")
        expect(result).to eq(' tabindex="1"')
      end

      it "parses float values" do
        result = build_dynamic('"data-opacity": 0.5')
        expect(result).to eq(' data-opacity="0.5"')
      end
    end

    context "boolean attributes" do
      it "outputs attribute name only for true" do
        result = build_dynamic("disabled: true")
        expect(result).to eq(" disabled")
        expect(result).not_to include('="')
      end

      it "omits attribute for false (HTML boolean)" do
        result = build_dynamic("disabled: false")
        expect(result).not_to include("disabled")
      end

      it "omits attribute for nil" do
        result = build_dynamic("disabled: nil")
        expect(result).not_to include("disabled")
      end

      it "outputs checked attribute for true" do
        result = build_dynamic("checked: true")
        expect(result).to eq(" checked")
      end

      it "omits checked attribute for false" do
        result = build_dynamic("checked: false")
        expect(result).not_to include("checked")
      end
    end

    context "ARIA and data boolean attributes" do
      it "outputs aria attribute with false as string" do
        result = build_dynamic('"aria-expanded": false')
        expect(result).to include('aria-expanded="false"')
      end

      it "outputs aria attribute with true as string" do
        result = build_dynamic('"aria-hidden": true')
        expect(result).to include('aria-hidden="true"')
      end

      it "outputs data attribute with false as string" do
        result = build_dynamic("data: { active: false }")
        expect(result).to include('data-active="false"')
      end

      it "outputs data attribute with true as string" do
        result = build_dynamic("data: { loading: true }")
        expect(result).to include('data-loading="true"')
      end
    end

    context "dynamic expressions (ERB output)" do
      it "wraps method calls in ERB" do
        result = build_dynamic("href: url_for(@item)")
        expect(result).to include('href="<%= url_for(@item) %>"')
      end

      it "wraps method chains in ERB" do
        result = build_dynamic("value: @user.address.city")
        expect(result).to include('value="<%= @user.address.city %>"')
      end

      it "wraps ternary operators in ERB" do
        result = build_dynamic('class: active? ? "on" : "off"')
        expect(result).to include("<%=")
        expect(result).to include("active?")
      end

      it "generates conditional ERB for dynamic boolean attributes" do
        result = build_dynamic("checked: is_checked")
        expect(result).to include("<%= 'checked' if (is_checked) %>")
      end

      it "wraps dynamic value in regular ERB for ARIA attributes" do
        result = build_dynamic('"aria-expanded": panel_open')
        expect(result).to include('aria-expanded="<%= panel_open %>"')
      end
    end

    context "array values" do
      it "joins array class values with spaces" do
        result = build_dynamic('class: ["foo", "bar", "baz"]')
        expect(result).to include('class="foo bar baz"')
      end

      it "JSON encodes non-class array values" do
        result = build_dynamic('data: { tags: ["a", "b"] }')
        expect(result).to include('data-tags="[&quot;a&quot;,&quot;b&quot;]"')
      end

      it "JSON encodes top-level array attributes" do
        result = build_dynamic('"data-items": ["x", "y"]')
        expect(result).to include('data-items="[&quot;x&quot;,&quot;y&quot;]"')
      end
    end

    context "nested data/aria hashes" do
      it "expands nested data attributes" do
        result = build_dynamic('data: { action: "click", value: "test" }')
        expect(result).to include('data-action="click"')
        expect(result).to include('data-value="test"')
      end

      it "expands nested aria attributes" do
        result = build_dynamic("aria: { expanded: true, hidden: false }")
        expect(result).to include('aria-expanded="true"')
        expect(result).to include('aria-hidden="false"')
      end

      it "expands dynamic values in nested hashes" do
        result = build_dynamic('data: { controller: "map", lat: location.lat }')
        expect(result).to include('data-controller="map"')
        expect(result).to include('data-lat="<%= location.lat %>"')
      end
    end

    context "string interpolation in attributes" do
      it "converts interpolation to ERB" do
        result = build_dynamic('id: "item-#{@item.id}"')
        expect(result).to include("id=")
        expect(result).to include("<%= @item.id %>")
      end

      it "preserves Stimulus action syntax" do
        result = build_dynamic('data: { action: "change->form#submit" }')
        expect(result).to include('data-action="change->form#submit"')
        expect(result).not_to include("&gt;")
      end
    end

    context "old-style hash rocket syntax" do
      it "parses :symbol => value syntax" do
        result = build_dynamic(':href => "/path"')
        expect(result).to include('href="/path"')
      end

      it "parses string key with hash rocket" do
        result = build_dynamic('"aria-label" => "Close"')
        expect(result).to include('aria-label="Close"')
      end
    end

    context "double splat (unsupported)" do
      it "skips double splat with warning" do
        expect { build_dynamic("**options") }
          .to output(/WARNING.*Double splat.*not supported/i).to_stderr
      end

      it "preserves other attributes when double splat present" do
        result = nil
        expect { result = build_dynamic('alt: "Image", **extra, title: "Title"') }
          .to output(/WARNING/).to_stderr
        expect(result).to include('alt="Image"')
        expect(result).to include('title="Title"')
      end
    end

    context "escaping" do
      it "escapes & in attribute values" do
        result = build_dynamic('href: "/search?a=1&b=2"')
        expect(result).to include('href="/search?a=1&amp;b=2"')
      end

      it "escapes quotes in attribute values" do
        result = build_dynamic('title: "Say \\"Hello\\""')
        expect(result).to include("title=")
      end
    end

    context "static attribute escaping" do
      it "escapes ampersand in static attribute values" do
        result = builder.build({ "href" => "/search?a=1&b=2" }, nil, nil)
        expect(result).to include('href="/search?a=1&amp;b=2"')
      end

      it "preserves angle brackets in static attributes (Stimulus)" do
        result = builder.build({ "data-action" => "click->form#submit" }, nil, nil)
        expect(result).to include('data-action="click->form#submit"')
      end
    end
  end
end
