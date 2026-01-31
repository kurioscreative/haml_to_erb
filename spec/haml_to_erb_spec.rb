# frozen_string_literal: true

require "spec_helper"
require "herb"

RSpec.describe HamlToErb do
  # Custom matcher to validate ERB syntax using Herb parser
  RSpec::Matchers.define :be_valid_erb do
    match do |erb|
      @result = Herb.parse(erb)
      @result.success?
    end

    failure_message do |erb|
      errors = @result.errors.map { |e| "  - #{e.message}" }.join("\n")
      "expected valid ERB, but got parse errors:\n#{errors}\n\nERB content:\n#{erb}"
    end
  end

  def convert(haml)
    described_class.convert(haml)
  end

  # Convert and validate that output is valid ERB
  def convert_and_validate(haml)
    erb = convert(haml)
    expect(erb).to be_valid_erb
    erb
  end

  describe ".convert" do
    context "ERB validity (using Herb parser)" do
      # These tests verify that generated ERB is syntactically valid
      # using the Herb HTML+ERB parser

      it "produces valid ERB for simple tags" do
        expect(convert("%div")).to be_valid_erb
        expect(convert("%p Hello")).to be_valid_erb
        expect(convert("%br/")).to be_valid_erb
      end

      it "produces valid ERB for nested structures" do
        haml = <<~HAML
          %div
            %ul
              %li First
              %li Second
        HAML
        expect(convert(haml)).to be_valid_erb
      end

      it "produces valid ERB for Ruby output" do
        expect(convert("= @title")).to be_valid_erb
        expect(convert("%h1= @title")).to be_valid_erb
      end

      it "produces valid ERB for control flow" do
        haml = <<~HAML
          - if condition
            %p True
          - else
            %p False
        HAML
        expect(convert(haml)).to be_valid_erb
      end

      it "produces valid ERB for blocks" do
        haml = <<~HAML
          = form_for @user do |f|
            = f.text_field :name
        HAML
        expect(convert(haml)).to be_valid_erb
      end

      it "produces valid ERB for filters" do
        haml = <<~HAML
          :javascript
            alert('hello');
        HAML
        expect(convert(haml)).to be_valid_erb
      end

      it "produces valid ERB for complex real-world templates" do
        haml = <<~HAML
          !!!
          %html
            %head
              %title= @title
            %body
              %header
                = render 'nav'
              %main
                - if @user
                  %h1 Welcome, \#{@user.name}
                - else
                  %p Please sign in
              %footer
                %p Copyright 2024
        HAML
        expect(convert(haml)).to be_valid_erb
      end
    end

    context "basic tags" do
      it "converts %div to <div></div>" do
        expect(convert("%div")).to eq("<div></div>\n")
      end

      it "converts %span to <span></span>" do
        expect(convert("%span")).to eq("<span></span>\n")
      end

      it "converts self-closing tags" do
        expect(convert("%br/")).to eq("<br>\n")
        expect(convert("%hr/")).to eq("<hr>\n")
        expect(convert("%img/")).to eq("<img>\n")
      end

      it "converts %p with text content" do
        expect(convert("%p Hello world")).to eq("<p>Hello world</p>\n")
      end
    end

    context "classes and IDs" do
      it "converts %div.foo to <div class='foo'>" do
        expect(convert("%div.foo")).to eq("<div class=\"foo\"></div>\n")
      end

      it "converts %div#bar to <div id='bar'>" do
        expect(convert("%div#bar")).to eq("<div id=\"bar\"></div>\n")
      end

      it "converts multiple classes" do
        expect(convert("%div.foo.bar")).to eq("<div class=\"foo bar\"></div>\n")
      end

      it "converts class and ID together" do
        result = convert("%div.foo#bar")
        expect(result).to include('class="foo"')
        expect(result).to include('id="bar"')
      end

      it "uses implicit div for .class" do
        expect(convert(".foo")).to eq("<div class=\"foo\"></div>\n")
      end

      it "uses implicit div for #id" do
        expect(convert("#bar")).to eq("<div id=\"bar\"></div>\n")
      end

      it "combines implicit div with class and ID" do
        result = convert(".foo#bar")
        expect(result).to include("<div")
        expect(result).to include('class="foo"')
        expect(result).to include('id="bar"')
      end
    end

    context "Ruby hash attributes" do
      it "converts single attribute" do
        expect(convert('%a{ href: "/path" }')).to eq('<a href="/path"></a>' + "\n")
      end

      it "converts multiple attributes" do
        result = convert('%a{ href: "/path", target: "_blank" }')
        expect(result).to include('href="/path"')
        expect(result).to include('target="_blank"')
      end

      it "merges shorthand class with hash class attribute" do
        result = convert('%nav.page-nav{ class: "navbar" }')
        expect(result).to include('class="page-nav navbar"')
        # Should NOT have duplicate class attributes
        expect(result.scan(/class=/).count).to eq(1)
      end

      it "merges multiple shorthand classes with hash class" do
        result = convert('%div.foo.bar{ class: "baz qux" }')
        expect(result).to include('class="foo bar baz qux"')
        expect(result.scan(/class=/).count).to eq(1)
      end

      it "converts nested data attributes" do
        result = convert('%div{ data: { action: "click", value: "test" } }')
        expect(result).to include('data-action="click"')
        expect(result).to include('data-value="test"')
      end

      it "expands nested data attributes with dynamic values" do
        result = convert('%div{ data: { controller: "map", "map-lat-value": location.lat, "map-lng-value": location.lng } }')
        expect(result).to include('data-controller="map"')
        expect(result).to include('data-map-lat-value="<%= location.lat %>"')
        expect(result).to include('data-map-lng-value="<%= location.lng %>"')
        # Should NOT have data= with a hash
        expect(result).not_to include('data="<%=')
      end

      it "converts boolean true to attribute presence" do
        # Input is a void element, no closing tag in HTML5
        expect(convert("%input{ disabled: true }")).to eq("<input disabled>\n")
      end

      it "omits attribute for boolean false" do
        expect(convert("%input{ disabled: false }")).to eq("<input>\n")
      end

      it "omits attribute for nil" do
        expect(convert("%input{ disabled: nil }")).to eq("<input>\n")
      end

      it "converts symbol values" do
        expect(convert("%input{ type: :text }")).to eq("<input type=\"text\">\n")
      end

      it "converts numeric values" do
        expect(convert("%input{ tabindex: 1 }")).to eq("<input tabindex=\"1\">\n")
      end
    end

    context "HTML-style attributes (parentheses)" do
      it "converts meta charset" do
        expect(convert('%meta(charset="utf-8")/')).to include('charset="utf-8"')
      end

      it "converts html lang" do
        expect(convert('%html(lang="en")')).to include('lang="en"')
      end
    end

    context "Ruby output (=)" do
      it "converts = to ERB output" do
        expect(convert("= @title")).to eq("<%= @title %>\n")
      end

      it "converts tag with = to ERB inside tag" do
        expect(convert("%h1= @title")).to eq("<h1><%= @title %></h1>\n")
      end

      it "converts method calls" do
        expect(convert("= link_to 'Home', root_path")).to eq("<%= link_to 'Home', root_path %>\n")
      end

      it "converts helper with block and nested content" do
        haml = <<~HAML
          = form_for @user do |f|
            = f.text_field :name
        HAML

        result = convert(haml)
        expect(result).to include("<%= form_for @user do |f| %>")
        expect(result).to include("<%= f.text_field :name %>")
        expect(result).to include("<% end %>")
      end
    end

    context "silent Ruby (-)" do
      it "converts - to ERB silent tag" do
        expect(convert("- x = 1")).to eq("<% x = 1 %>\n")
      end

      it "wraps silent Ruby in ERB silent tags (no output)" do
        result = convert("- @var = 'value'")
        # Should use <% %> not <%= %> - no output to HTML
        expect(result).to eq("<% @var = 'value' %>\n")
        expect(result).not_to include("<%=")
      end
    end

    context "control flow" do
      it "converts if/else/end" do
        haml = <<~HAML
          - if condition
            %p True
          - else
            %p False
        HAML

        result = convert(haml)
        expect(result).to include("<% if condition %>")
        expect(result).to include("<p>True</p>")
        expect(result).to include("<% else %>")
        expect(result).to include("<p>False</p>")
        expect(result).to include("<% end %>")
      end

      it "converts unless" do
        haml = <<~HAML
          - unless condition
            %p Show this
        HAML

        result = convert(haml)
        expect(result).to include("<% unless condition %>")
        expect(result).to include("<% end %>")
      end

      it "converts case/when" do
        haml = <<~HAML
          - case status
          - when :active
            %p Active
          - when :pending
            %p Pending
        HAML

        result = convert(haml)
        expect(result).to include("<% case status %>")
        expect(result).to include("<% when :active %>")
        expect(result).to include("<% when :pending %>")
      end

      it "converts elsif" do
        haml = <<~HAML
          - if a
            %p A
          - elsif b
            %p B
        HAML

        result = convert(haml)
        expect(result).to include("<% if a %>")
        expect(result).to include("<% elsif b %>")
        expect(result).to include("<% end %>")
      end
    end

    context "blocks with do" do
      it "converts each block" do
        haml = <<~HAML
          - @items.each do |item|
            %li= item.name
        HAML

        result = convert(haml)
        expect(result).to include("<% @items.each do |item| %>")
        expect(result).to include("<li><%= item.name %></li>")
        expect(result).to include("<% end %>")
      end

      it "converts output block with do" do
        haml = <<~HAML
          = link_to root_path do
            %span Home
        HAML

        result = convert(haml)
        expect(result).to include("<%= link_to root_path do %>")
        expect(result).to include("<span>Home</span>")
        expect(result).to include("<% end %>")
      end
    end

    context "filters" do
      it "converts :javascript filter" do
        haml = <<~HAML
          :javascript
            alert('hello');
        HAML

        result = convert(haml)
        expect(result).to include("<script>")
        expect(result).to include("alert('hello');")
        expect(result).to include("</script>")
      end

      it "converts :css filter" do
        haml = <<~HAML
          :css
            .foo { color: red; }
        HAML

        result = convert(haml)
        expect(result).to include("<style>")
        expect(result).to include(".foo { color: red; }")
        expect(result).to include("</style>")
      end

      it "converts :plain filter" do
        haml = <<~HAML
          :plain
            Just plain text
        HAML

        result = convert(haml)
        expect(result).to include("Just plain text")
        expect(result).not_to include("<p>")
      end

      it "converts :erb filter" do
        haml = <<~HAML
          :erb
            <%= @value %>
        HAML

        result = convert(haml)
        expect(result).to include("<%= @value %>")
      end

      it "converts interpolation within :javascript filter" do
        haml = <<~HAML
          :javascript
            var x = '\#{@value}';
        HAML

        result = convert(haml)
        expect(result).to include("<script>")
        expect(result).to include("@value")
        expect(result).to include("</script>")
      end
    end

    context "interpolation" do
      # HAML parser treats interpolated strings as Ruby expressions,
      # wrapping the whole string in ERB output tags
      it "converts interpolation in plain text" do
        result = convert('Hello #{name}')
        expect(result).to include("Hello")
        expect(result).to include("name")
        expect(result).to include("<%=")
      end

      it "converts multiple interpolations" do
        result = convert('Hello #{first} #{last}')
        expect(result).to include("first")
        expect(result).to include("last")
        expect(result).to include("<%=")
      end

      it "converts interpolation in tag content" do
        result = convert('%p Hello #{name}')
        expect(result).to include("<p>")
        expect(result).to include("</p>")
        expect(result).to include("name")
      end

      it "handles nested braces in interpolation" do
        result = convert('Value: #{hash[:key]}')
        expect(result).to include("hash[:key]")
        expect(result).to include("<%=")
      end

      it "converts tag with interpolated helper methods to separate ERB tags" do
        # This pattern is common: %p #{link_to "Home", path} or #{link_to "Login", login_path}
        # Should NOT wrap in a string literal which would escape the HTML from helpers
        result = convert('%p #{link_to "Home", root_path} or #{link_to "Sign in", login_path} please.')
        expect(result).to include("<p>")
        expect(result).to include("<%= link_to \"Home\", root_path %>")
        expect(result).to include(" or ")
        expect(result).to include("<%= link_to \"Sign in\", login_path %>")
        expect(result).to include(" please.")
        expect(result).to include("</p>")
        # Should NOT have the whole thing wrapped in a string literal
        expect(result).not_to include('<%=  "')
        expect(result).not_to include('<%= "#{')
      end
    end

    context "escaped interpolation" do
      it 'preserves \#{expr} as literal #{expr}' do
        # Use the Interpolation module directly to test escaping
        result = HamlToErb::Interpolation.convert('Hello \#{name}')
        expect(result).to eq('Hello #{name}')
        expect(result).not_to include("<%=")
      end

      it 'converts \\\\#{expr} to \\<%= expr %>' do
        # Double backslash = escaped backslash + unescaped interpolation
        result = HamlToErb::Interpolation.convert('Path: \\\\#{value}')
        expect(result).to include("\\<%= value %>")
      end

      it "handles mixed escaped and unescaped interpolations" do
        result = HamlToErb::Interpolation.convert('#{real} and \#{literal}')
        expect(result).to include("<%= real %>")
        expect(result).to include("\#{literal}")
        expect(result).not_to include("<%= literal %>")
      end
    end

    context "comments" do
      it "converts HTML comments" do
        expect(convert("/ This is a comment")).to include("<!-- This is a comment -->")
      end

      it "omits HAML comments from output" do
        result = convert("-# This is a HAML comment")
        expect(result).not_to include("HAML comment")
        expect(result).not_to include("<!--")
      end
    end

    context "doctype" do
      it "converts !!! to DOCTYPE" do
        expect(convert("!!!")).to eq("<!DOCTYPE html>\n")
      end

      it "converts !!! 5 to DOCTYPE" do
        expect(convert("!!! 5")).to eq("<!DOCTYPE html>\n")
      end

      # Note: The converter currently outputs HTML5 doctype for all variations
      # XML declaration support could be added if needed
      it "defaults to HTML5 DOCTYPE for other variants" do
        expect(convert("!!! Strict")).to eq("<!DOCTYPE html>\n")
      end
    end

    context "plain text" do
      it "outputs plain text as-is" do
        expect(convert("Hello world")).to eq("Hello world\n")
      end
    end

    context "nesting" do
      it "preserves nested structure" do
        haml = <<~HAML
          %div
            %p
              %span Text
        HAML

        result = convert(haml)
        expect(result).to include("<div>")
        expect(result).to include("<p>")
        expect(result).to include("<span>Text</span>")
        expect(result).to include("</p>")
        expect(result).to include("</div>")
      end

      it "indents nested elements properly" do
        haml = <<~HAML
          %ul
            %li First
            %li Second
        HAML

        result = convert(haml)
        lines = result.lines
        ul_line = lines.find { |l| l.include?("<ul>") }
        li_line = lines.find { |l| l.include?("<li>") }

        # li should be indented more than ul
        expect(li_line).to start_with("  ")
      end
    end

    context "dynamic attributes" do
      # Note: Instance variables like @url evaluate to nil in the converter context,
      # so they get treated as falsy and omitted. Use method calls to test dynamic behavior.
      it "wraps method calls in ERB output tags" do
        result = convert("%a{ href: url_for(@item) }")
        expect(result).to include('href="<%= url_for(@item) %>"')
      end

      it "handles string interpolation in attributes" do
        result = convert('%a{ href: "/users/#{@user.id}" }')
        expect(result).to include("@user.id")
      end

      it "handles method calls in attributes" do
        result = convert("%input{ value: current_user.name }")
        expect(result).to include("current_user.name")
      end
    end

    context "edge cases: unescaped output (==)" do
      it "converts == to unescaped ERB output" do
        result = convert('== #{@value}')
        # The HAML parser treats == as plain text with interpolation
        expect(result).to include("@value")
      end

      it "converts == with HTML entities" do
        result = convert('== &copy; #{@year}')
        expect(result).to include("&copy;")
        expect(result).to include("@year")
      end
    end

    context "edge cases: old-style hash rocket syntax" do
      it "converts old-style :symbol => value syntax" do
        result = convert('%a{ :href => "/path" }')
        expect(result).to include('href="/path"')
      end

      it "converts mixed old and new hash syntax" do
        result = convert('%a{ :href => "/path", target: "_blank" }')
        expect(result).to include('href="/path"')
        expect(result).to include('target="_blank"')
      end

      it "converts string keys with hash rocket" do
        result = convert('%div{ "aria-label" => "Close" }')
        expect(result).to include('aria-label="Close"')
      end
    end

    context "edge cases: ternary operators in attributes" do
      it "wraps ternary operators with undefined methods in ERB" do
        # Uses method call that can't be evaluated at conversion time
        result = convert('%div{ class: is_active? ? "active" : "inactive" }')
        expect(result).to include("<%=")
        expect(result).to include("is_active?")
      end

      it "handles complex ternary with method calls in ERB" do
        result = convert('%input{ class: user_type == "admin" ? "admin-input" : "user-input" }')
        expect(result).to include("<%=")
        expect(result).to include("user_type")
      end
    end

    context "edge cases: double splat for hash expansion" do
      # NOTE: Double splat is not currently supported by the converter's
      # dynamic attribute parser. The ** expression is skipped with a warning,
      # but subsequent attributes are still parsed and preserved.

      it "skips double splat operator with warning but continues parsing" do
        expect { convert("%img{ **image_options }") }
          .to output(/WARNING.*Double splat.*not supported/i).to_stderr
      end

      it "preserves attributes before double splat" do
        result = nil
        expect { result = convert('%img{ alt: "Image", **helper_method(@arg) }') }
          .to output(/WARNING/).to_stderr
        expect(result).to include('alt="Image"')
      end

      it "preserves attributes after double splat" do
        result = nil
        expect { result = convert('%img{ **helper_method(@arg), alt: "Image", title: "Title" }') }
          .to output(/WARNING/).to_stderr
        expect(result).to include('alt="Image"')
        expect(result).to include('title="Title"')
      end
    end

    context "edge cases: string concatenation in attributes" do
      it "wraps string concatenation in ERB" do
        result = convert('%a{ href: "/users/" + @user.id.to_s }')
        expect(result).to include("<%=")
        expect(result).to include('"/users/" + @user.id.to_s')
      end
    end

    context "edge cases: void elements with nested children" do
      # HTML5 void elements (input, br, img, etc.) cannot have children.
      # When HAML nests children under a void element, the converter warns
      # and emits children as siblings rather than silently breaking.

      it "warns when void element has nested children" do
        haml = <<~HAML
          %input{type: 'checkbox'}
            %label Checkbox label
        HAML

        expect { convert(haml) }.to output(/WARNING.*Void element.*<input>.*nested children/i).to_stderr
      end

      it "emits children as siblings for void elements" do
        haml = <<~HAML
          %input{type: 'checkbox', id: 'my-checkbox'}
            %label{for: 'my-checkbox'} Click me
        HAML

        result = convert(haml)
        # Input should not have closing tag
        expect(result).to include("<input")
        expect(result).not_to include("</input>")
        # Label should be present as sibling
        expect(result).to include("<label")
        expect(result).to include("Click me")
        expect(result).to include("</label>")
      end

      it "handles deeply nested content under void elements" do
        haml = <<~HAML
          %input.form-check-input{type: 'checkbox'}
            %label.form-check-label
              %span.label-text Label
        HAML

        result = convert(haml)
        expect(result).to include("<input")
        expect(result).not_to include("</input>")
        expect(result).to include("<label")
        expect(result).to include("<span")
      end
    end

    context "edge cases: begin/rescue/ensure blocks" do
      it "converts begin/rescue/ensure" do
        haml = <<~HAML
          - begin
            %p Try this
          - rescue
            %p Error occurred
          - ensure
            %p Always runs
        HAML

        result = convert(haml)
        expect(result).to include("<% begin %>")
        expect(result).to include("<% rescue %>")
        expect(result).to include("<% ensure %>")
        expect(result).to include("<% end %>")
      end
    end

    context "edge cases: while/until/for loops" do
      it "converts while loop with end tag" do
        haml = <<~HAML
          - while condition
            %p Looping
        HAML

        result = convert(haml)
        expect(result).to include("<% while condition %>")
        expect(result).to include("<p>Looping</p>")
        expect(result).to include("<% end %>")
      end

      it "converts until loop with end tag" do
        haml = <<~HAML
          - until done
            %p Working
        HAML

        result = convert(haml)
        expect(result).to include("<% until done %>")
        expect(result).to include("<p>Working</p>")
        expect(result).to include("<% end %>")
      end

      it "converts for loop with end tag" do
        haml = <<~HAML
          - for i in 1..5
            %p= i
        HAML

        result = convert(haml)
        expect(result).to include("<% for i in 1..5 %>")
        expect(result).to include("<p><%= i %></p>")
        expect(result).to include("<% end %>")
      end

      it "handles .each with do properly" do
        haml = <<~HAML
          - (1..5).each do |i|
            %p= i
        HAML

        result = convert(haml)
        expect(result).to include("<% (1..5).each do |i| %>")
        expect(result).to include("<% end %>")
      end
    end

    context "edge cases: XML doctype" do
      it "converts !!! XML to XML declaration" do
        result = convert("!!! XML")
        expect(result).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
      end

      it "uses default encoding for XML declaration" do
        result = convert("!!! XML")
        expect(result).to include('encoding="UTF-8"')
      end
    end

    context "edge cases: ruby filter" do
      it "converts :ruby filter to ERB silent code" do
        haml = <<~HAML
          :ruby
            x = 1
            y = 2
        HAML

        result = convert(haml)
        expect(result).to include("<% x = 1 %>")
        expect(result).to include("<% y = 2 %>")
      end

      it "handles complex ruby code in filter" do
        haml = <<~HAML
          :ruby
            @items = Item.all
            total = @items.sum(&:price)
        HAML

        result = convert(haml)
        expect(result).to include("<% @items = Item.all %>")
        expect(result).to include("<% total = @items.sum(&:price) %>")
      end
    end

    context "edge cases: object reference syntax" do
      it "converts %div[@user] to ERB class and id" do
        result = convert("%div[@user]")
        expect(result).to include("<div")
        expect(result).to include('class="<%= @user.class.name.underscore %>"')
        expect(result).to include("id=\"<%= @user.class.name.underscore + '_' + @user.to_key.first.to_s %>\"")
      end

      it "converts object reference with prefix" do
        result = convert("%tr[@item, :row]")
        expect(result).to include("<tr")
        expect(result).to include('class="<%= "row_" + @item.class.name.underscore %>"')
        expect(result).to include('id="<%= "row_" + @item.class.name.underscore')
      end

      it "combines object reference with other attributes" do
        result = convert('%div[@user]{ data: { controller: "user" } }')
        expect(result).to include('class="<%= @user.class.name.underscore %>"')
        expect(result).to include('data-controller="user"')
      end
    end

    context "edge cases: unknown filters" do
      it "outputs comment for unknown filters" do
        haml = <<~HAML
          :markdown
            # Heading
            Some text
        HAML

        result = convert(haml)
        expect(result).to include("<!-- Unknown filter: markdown -->")
      end
    end

    context "edge cases: ID merging" do
      it "merges shorthand ID with hash ID" do
        result = convert('#foo{ id: "bar" }')
        expect(result).to include('id="foo bar"')
        expect(result.scan(/id=/).count).to eq(1)
      end
    end

    context "edge cases: float numbers in attributes" do
      it "converts float values" do
        result = convert('%div{ "data-opacity": 0.5 }')
        expect(result).to include('data-opacity="0.5"')
      end
    end

    context "edge cases: array values in attributes" do
      it "joins array class values with spaces" do
        result = convert('%div{ class: ["foo", "bar", "baz"] }')
        expect(result).to include('class="foo bar baz"')
      end

      it "JSON encodes array data values for Stimulus compatibility" do
        result = convert('%div{ data: { tags: ["a", "b"] } }')
        # Non-class arrays are JSON encoded for Stimulus value attributes
        # Only & and " are escaped in attribute values (not < >)
        expect(result).to include('data-tags="[&quot;a&quot;,&quot;b&quot;]"')
      end

      it "JSON encodes top-level array attributes" do
        result = convert('%div{ "data-list-filter-fields-value": ["category-name"] }')
        expect(result).to include('data-list-filter-fields-value="[&quot;category-name&quot;]"')
      end

      it "preserves > in data-action attributes" do
        result = convert('%input{ data: { action: "change->form#submit" } }')
        expect(result).to include('data-action="change->form#submit"')
        expect(result).not_to include("&gt;")
      end
    end

    context "edge cases: method chains in attributes" do
      it "wraps method chains in ERB" do
        result = convert("%input{ value: @user.address.city }")
        expect(result).to include('value="<%= @user.address.city %>"')
      end

      it "wraps method calls with arguments in ERB" do
        result = convert("%div{ title: truncate(@text, length: 50) }")
        expect(result).to include("<%=")
        expect(result).to include("truncate(@text, length: 50)")
      end
    end

    context "edge cases: deeply nested interpolation" do
      it "handles nested hash access in interpolation" do
        result = convert('Value: #{hash[:outer][:inner]}')
        expect(result).to include("<%= hash[:outer][:inner] %>")
      end

      it "handles method calls with blocks in interpolation" do
        result = convert('Total: #{items.sum { |i| i.price }}')
        expect(result).to include("items.sum")
      end

      it "handles strings with braces inside interpolation" do
        result = convert('Value: #{"hello {world}"}')
        expect(result).to include('<%= "hello {world}" %>')
      end
    end

    context "edge cases: whitespace removal markers" do
      it "handles > (remove outer whitespace)" do
        haml = <<~HAML
          %span> text
        HAML
        result = convert(haml)
        expect(result).to include("<span>")
        expect(result).to include("text")
      end

      it "handles < (remove inner whitespace)" do
        haml = <<~HAML
          %span<
            text
        HAML
        result = convert(haml)
        expect(result).to include("<span>")
      end
    end

    context "edge cases: special characters in values" do
      it "escapes special characters in static attribute values" do
        result = convert('%div{ title: "Say \\"Hello\\"" }')
        expect(result).to include("title=")
      end

      it "handles ampersands in values" do
        result = convert('%a{ href: "/search?a=1&b=2" }')
        expect(result).to include("a=1")
        expect(result).to include("b=2")
      end
    end

    context "edge cases: multiline content" do
      it "handles tags with multiline text content" do
        haml = <<~HAML
          %p
            This is a long
            multiline paragraph
        HAML
        result = convert(haml)
        expect(result).to include("<p>")
        expect(result).to include("This is a long")
        expect(result).to include("multiline paragraph")
        expect(result).to include("</p>")
      end
    end

    context "edge cases: empty constructs" do
      it "handles if with no else" do
        haml = <<~HAML
          - if condition
            %p Show this
        HAML
        result = convert(haml)
        expect(result).to include("<% if condition %>")
        expect(result).to include("<% end %>")
        expect(result).not_to include("<% else %>")
      end

      it "handles block with no children" do
        # Silent script with block keyword but no children shouldn't add end
        result = convert("- if true")
        expect(result).to eq("<% if true %>\n")
        expect(result).not_to include("<% end %>")
      end
    end

    context "complex real-world examples" do
      it "converts a form with nested elements" do
        haml = <<~HAML
          = form_for @user do |f|
            .form-group
              = f.label :name
              = f.text_field :name, class: 'form-control'
            .form-group
              = f.submit 'Save'
        HAML

        result = convert(haml)
        expect(result).to include("<%= form_for @user do |f| %>")
        expect(result).to include('<div class="form-group">')
        expect(result).to include("<%= f.label :name %>")
        expect(result).to include("<%= f.text_field :name, class: 'form-control' %>")
        expect(result).to include("<%= f.submit 'Save' %>")
        expect(result).to include("<% end %>")
      end

      it "converts conditional rendering" do
        haml = <<~HAML
          - if @user.admin?
            %p.admin Admin user
          - else
            %p.regular Regular user
        HAML

        result = convert(haml)
        expect(result).to include("<% if @user.admin? %>")
        expect(result).to include('<p class="admin">Admin user</p>')
        expect(result).to include("<% else %>")
        expect(result).to include('<p class="regular">Regular user</p>')
        expect(result).to include("<% end %>")
      end

      it "converts a loop with index" do
        haml = <<~HAML
          - @items.each_with_index do |item, index|
            %tr
              %td= index + 1
              %td= item.name
        HAML

        result = convert(haml)
        expect(result).to include("<% @items.each_with_index do |item, index| %>")
        expect(result).to include("<tr>")
        expect(result).to include("<td><%= index + 1 %></td>")
        expect(result).to include("<td><%= item.name %></td>")
        expect(result).to include("</tr>")
        expect(result).to include("<% end %>")
      end
    end

    context "boolean HTML attributes vs ARIA/data attributes" do
      # HTML5 boolean attributes (checked, disabled, etc.) should only output
      # the attribute name when true, and omit entirely when false.
      # ARIA and data attributes should output "false" as a string value.

      it "omits boolean HTML attribute when value is false" do
        result = convert("%input{ checked: false }")
        expect(result).not_to include("checked")
      end

      it "outputs ARIA attribute with false as string value" do
        result = convert('%button{ "aria-expanded": false }')
        expect(result).to include('aria-expanded="false"')
      end

      it "outputs ARIA attribute with true as string value" do
        result = convert("%button{ aria: { expanded: true, haspopup: true } }")
        expect(result).to include('aria-expanded="true"')
        expect(result).to include('aria-haspopup="true"')
      end

      it "outputs data attribute with false as string value" do
        result = convert("%div{ data: { active: false } }")
        expect(result).to include('data-active="false"')
      end

      it "outputs conditional ERB for dynamic boolean attributes" do
        result = convert("%input{ checked: some_condition }")
        expect(result).to include("<%= 'checked' if (some_condition) %>")
        expect(result).not_to include('checked="<%= some_condition %>"')
      end

      it "outputs regular ERB for dynamic ARIA attributes" do
        result = convert('%button{ "aria-expanded": panel_open }')
        expect(result).to include('aria-expanded="<%= panel_open %>"')
      end

      it "handles multiple boolean attributes with mixed values" do
        result = convert('%input{ type: "checkbox", checked: is_checked, disabled: false, required: true }')
        expect(result).to include('type="checkbox"')
        expect(result).to include("<%= 'checked' if (is_checked) %>")
        expect(result).not_to include("disabled")
        expect(result).to include("required")
        expect(result).not_to include('required="')
      end

      it "handles real-world checkbox pattern with dynamic checked attribute" do
        haml = <<~HAML
          %input.form-check-input{type: 'checkbox',
                id: "dropdown-category-\#{category.slug}",
                checked: filters && filters[:tags] && filters[:tags].include?(category.name),
                data: { action: 'change->form#submit' }}
        HAML

        result = convert(haml)
        expect(result).to include('type="checkbox"')
        expect(result).to include("<%= 'checked' if (filters && filters[:tags] && filters[:tags].include?(category.name)) %>")
        expect(result).to include('data-action="change->form#submit"')
      end
    end
  end

  describe HamlToErb::ValidationResult do
    it "stores erb and errors" do
      result = described_class.new(erb: "<p>test</p>", errors: [ { message: "error" } ])
      expect(result.erb).to eq("<p>test</p>")
      expect(result.errors).to eq([ { message: "error" } ])
    end

    it "returns valid? true when errors empty" do
      result = described_class.new(erb: "<p>test</p>", errors: [])
      expect(result.valid?).to be true
    end

    it "returns valid? false when errors present" do
      result = described_class.new(erb: "<p>", errors: [ { message: "unclosed tag" } ])
      expect(result.valid?).to be false
    end

    it "converts to hash with to_h" do
      result = described_class.new(erb: "<div></div>", errors: [])
      hash = result.to_h
      expect(hash).to eq({ erb: "<div></div>", valid: true, errors: [] })
    end
  end

  describe ".validate" do
    it "returns valid result for valid ERB" do
      result = HamlToErb.validate("<p><%= @name %></p>")
      expect(result.valid?).to be true
      expect(result.errors).to be_empty
    end

    it "returns invalid result for malformed ERB" do
      result = HamlToErb.validate("<%= if true %>")
      expect(result.valid?).to be false
      expect(result.errors).not_to be_empty
    end

    it "includes error details with message" do
      result = HamlToErb.validate("<%= unclosed")
      expect(result.errors.first).to have_key(:message)
    end
  end

  describe ".convert_and_validate" do
    it "converts and validates in one call" do
      result = HamlToErb.convert_and_validate("%p Hello")
      expect(result).to be_a(HamlToErb::ValidationResult)
      expect(result.erb).to include("<p>Hello</p>")
    end

    it "returns ValidationResult with erb content" do
      result = HamlToErb.convert_and_validate("%div.foo")
      expect(result.erb).to include('class="foo"')
    end

    it "reports validation errors for complex output" do
      result = HamlToErb.convert_and_validate("%p= @value")
      expect(result.valid?).to be true
    end
  end

  describe ".convert_file" do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:haml_path) { File.join(tmp_dir, "test.html.haml") }

    after do
      FileUtils.remove_entry(tmp_dir)
    end

    it "creates an .erb file from .haml file" do
      File.write(haml_path, "%h1 Hello")

      result = described_class.convert_file(haml_path)

      expect(result[:path]).to eq(File.join(tmp_dir, "test.html.erb"))
      expect(File.exist?(result[:path])).to be true
      expect(File.read(result[:path])).to include("<h1>Hello</h1>")
    end

    it "keeps original file by default" do
      File.write(haml_path, "%p Test")

      described_class.convert_file(haml_path)

      expect(File.exist?(haml_path)).to be true
    end

    it "deletes original file when delete_original: true" do
      File.write(haml_path, "%p Test")

      described_class.convert_file(haml_path, delete_original: true)

      expect(File.exist?(haml_path)).to be false
    end

    it "returns hash with path and empty errors" do
      File.write(haml_path, "%div")

      result = described_class.convert_file(haml_path)

      expect(result[:path]).to end_with(".erb")
      expect(result[:errors]).to be_empty
    end

    context "with validate: true" do
      it "includes validation errors in result" do
        File.write(haml_path, "%p= @value")
        result = described_class.convert_file(haml_path, validate: true)
        expect(result[:errors]).to be_an(Array)
      end

      it "returns empty errors for valid output" do
        File.write(haml_path, "%p Hello")
        result = described_class.convert_file(haml_path, validate: true)
        expect(result[:errors]).to be_empty
      end
    end

    context "error handling" do
      it "returns error for missing file" do
        result = described_class.convert_file("/nonexistent/path.haml")
        expect(result[:skipped]).to be true
        expect(result[:errors].first[:message]).to include("File not found")
      end

      it "continues processing and returns error details" do
        result = described_class.convert_file("/nonexistent.haml")
        expect(result[:path]).to eq("/nonexistent.erb")
        expect(result[:errors]).not_to be_empty
      end
    end

    context "with dry_run: true" do
      it "does not create erb file" do
        File.write(haml_path, "%p Dry run test")
        erb_path = haml_path.sub(/\.haml\z/, ".erb")

        described_class.convert_file(haml_path, dry_run: true)

        expect(File.exist?(erb_path)).to be false
      end

      it "does not delete original file" do
        File.write(haml_path, "%p Keep me")

        described_class.convert_file(haml_path, delete_original: true, dry_run: true)

        expect(File.exist?(haml_path)).to be true
      end

      it "returns content in result hash" do
        File.write(haml_path, "%p Content preview")

        result = described_class.convert_file(haml_path, dry_run: true)

        expect(result[:content]).to include("<p>Content preview</p>")
      end

      it "returns dry_run: true in result" do
        File.write(haml_path, "%div")

        result = described_class.convert_file(haml_path, dry_run: true)

        expect(result[:dry_run]).to be true
      end
    end
  end

  describe ".convert_directory" do
    let(:tmp_dir) { Dir.mktmpdir }

    after do
      FileUtils.remove_entry(tmp_dir)
    end

    it "converts all .haml files in directory" do
      File.write(File.join(tmp_dir, "one.html.haml"), "%h1 One")
      File.write(File.join(tmp_dir, "two.html.haml"), "%h2 Two")

      result = described_class.convert_directory(tmp_dir)

      expect(result.length).to eq(2)
      expect(File.exist?(File.join(tmp_dir, "one.html.erb"))).to be true
      expect(File.exist?(File.join(tmp_dir, "two.html.erb"))).to be true
    end

    it "converts files in subdirectories" do
      subdir = File.join(tmp_dir, "subdir")
      FileUtils.mkdir_p(subdir)
      File.write(File.join(subdir, "nested.html.haml"), "%p Nested")

      described_class.convert_directory(tmp_dir)

      expect(File.exist?(File.join(subdir, "nested.html.erb"))).to be true
    end

    it "keeps original files by default" do
      File.write(File.join(tmp_dir, "keep.html.haml"), "%div")

      described_class.convert_directory(tmp_dir)

      expect(File.exist?(File.join(tmp_dir, "keep.html.haml"))).to be true
    end

    it "deletes originals when delete_originals: true" do
      File.write(File.join(tmp_dir, "delete.html.haml"), "%div")

      described_class.convert_directory(tmp_dir, delete_originals: true)

      expect(File.exist?(File.join(tmp_dir, "delete.html.haml"))).to be false
    end

    it "returns array of result hashes with erb paths" do
      File.write(File.join(tmp_dir, "test.html.haml"), "%div")

      result = described_class.convert_directory(tmp_dir)

      expect(result.map { |r| r[:path] }).to all(end_with(".erb"))
    end

    context "with dry_run: true" do
      it "does not create any erb files" do
        File.write(File.join(tmp_dir, "one.html.haml"), "%h1 One")
        File.write(File.join(tmp_dir, "two.html.haml"), "%h2 Two")

        described_class.convert_directory(tmp_dir, dry_run: true)

        expect(File.exist?(File.join(tmp_dir, "one.html.erb"))).to be false
        expect(File.exist?(File.join(tmp_dir, "two.html.erb"))).to be false
      end

      it "returns content for each file" do
        File.write(File.join(tmp_dir, "test.html.haml"), "%p Preview")

        results = described_class.convert_directory(tmp_dir, dry_run: true)

        expect(results.first[:content]).to include("<p>Preview</p>")
        expect(results.first[:dry_run]).to be true
      end
    end

    context "with validate: true" do
      it "includes validation results for each file" do
        File.write(File.join(tmp_dir, "valid.html.haml"), "%p Valid")

        results = described_class.convert_directory(tmp_dir, validate: true)

        expect(results.first[:errors]).to be_an(Array)
      end
    end
  end
end
