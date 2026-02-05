# frozen_string_literal: true

require "spec_helper"

RSpec.describe HamlToErb::Converter do
  def convert(haml)
    described_class.new(haml).convert
  end

  describe "#convert" do
    context "basic tags" do
      it "converts %div to <div></div>" do
        expect(convert("%div")).to eq("<div></div>\n")
      end

      it "converts %span to <span></span>" do
        expect(convert("%span")).to eq("<span></span>\n")
      end

      it "converts %p with text content" do
        expect(convert("%p Hello world")).to eq("<p>Hello world</p>\n")
      end

      it "converts self-closing tags" do
        expect(convert("%br/")).to eq("<br>\n")
        expect(convert("%hr/")).to eq("<hr>\n")
        expect(convert("%img/")).to eq("<img>\n")
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
    end

    context "nesting and indentation" do
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
        li_line = lines.find { |l| l.include?("<li>") }
        expect(li_line).to start_with("  ")
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

      it "wraps silent Ruby in ERB silent tags" do
        result = convert("- @var = 'value'")
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

      it "handles while loop" do
        haml = <<~HAML
          - while condition
            %p Looping
        HAML

        result = convert(haml)
        expect(result).to include("<% while condition %>")
        expect(result).to include("<% end %>")
      end

      it "handles until loop" do
        haml = <<~HAML
          - until done
            %p Working
        HAML

        result = convert(haml)
        expect(result).to include("<% until done %>")
        expect(result).to include("<% end %>")
      end

      it "handles for loop" do
        haml = <<~HAML
          - for i in 1..5
            %p= i
        HAML

        result = convert(haml)
        expect(result).to include("<% for i in 1..5 %>")
        expect(result).to include("<% end %>")
      end

      it "handles begin/rescue/ensure" do
        haml = <<~HAML
          - begin
            %p Try this
          - rescue
            %p Error
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

      it "converts :ruby filter to silent ERB" do
        haml = <<~HAML
          :ruby
            x = 1
            y = 2
        HAML

        result = convert(haml)
        expect(result).to include("<% x = 1 %>")
        expect(result).to include("<% y = 2 %>")
      end

      it "converts interpolation within :javascript filter" do
        haml = <<~HAML
          :javascript
            var x = '\#{@value}';
        HAML

        result = convert(haml)
        expect(result).to include("<script>")
        expect(result).to include("@value")
      end

      it "outputs comment for unknown filters" do
        haml = <<~HAML
          :markdown
            # Heading
        HAML

        result = convert(haml)
        expect(result).to include("<!-- Unknown filter: markdown -->")
      end
    end

    context "doctype" do
      it "converts !!! to DOCTYPE" do
        expect(convert("!!!")).to eq("<!DOCTYPE html>\n")
      end

      it "converts !!! 5 to DOCTYPE" do
        expect(convert("!!! 5")).to eq("<!DOCTYPE html>\n")
      end

      it "converts !!! XML to XML declaration" do
        result = convert("!!! XML")
        expect(result).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
      end

      it "defaults to HTML5 DOCTYPE for other variants" do
        expect(convert("!!! Strict")).to eq("<!DOCTYPE html>\n")
      end
    end

    context "comments" do
      it "converts HTML comments" do
        result = convert("/ This is a comment")
        expect(result).to include("<!-- This is a comment -->")
      end

      it "omits HAML comments from output" do
        result = convert("-# This is a HAML comment")
        expect(result).not_to include("HAML comment")
        expect(result).not_to include("<!--")
      end
    end

    context "plain text" do
      it "outputs plain text as-is" do
        expect(convert("Hello world")).to eq("Hello world\n")
      end

      it "converts interpolation in plain text" do
        result = convert('Hello #{name}')
        expect(result).to include("Hello")
        expect(result).to include("<%= name %>")
      end
    end

    context "object reference syntax" do
      it "converts %div[@user] to ERB class and id" do
        result = convert("%div[@user]")
        expect(result).to include("<div")
        expect(result).to include('class="<%= @user.class.name.underscore %>"')
        expect(result).to include('id="<%= @user.class.name.underscore')
      end

      it "converts object reference with prefix" do
        result = convert("%tr[@item, :row]")
        expect(result).to include("<tr")
        expect(result).to include('"row_"')
      end
    end

    context "void elements with nested children" do
      it "warns when void element has nested children" do
        haml = <<~HAML
          %input{type: 'checkbox'}
            %label Checkbox label
        HAML

        expect { convert(haml) }.to output(/WARNING.*Void element.*<input>/i).to_stderr
      end

      it "emits children as siblings for void elements" do
        haml = <<~HAML
          %input{type: 'checkbox', id: 'my-checkbox'}
            %label{for: 'my-checkbox'} Click me
        HAML

        result = convert(haml)
        expect(result).to include("<input")
        expect(result).not_to include("</input>")
        expect(result).to include("<label")
        expect(result).to include("Click me")
      end
    end

    context "void elements with inline content" do
      it "warns when void element has inline content" do
        expect { convert("%br Hello") }.to output(/WARNING.*Void element.*<br>.*inline content/i).to_stderr
      end

      it "emits inline content as sibling for void elements" do
        result = convert("%img{src: 'test.jpg'} Caption")
        expect(result).to include("<img")
        expect(result).not_to include("</img>")
        expect(result).to include("Caption")
      end

      it "does not warn for void element without content" do
        expect { convert("%br") }.not_to output(/WARNING/i).to_stderr
      end
    end

    context "whitespace removal markers" do
      it "handles > (remove outer whitespace)" do
        result = convert("%span> text")
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

    context "empty constructs" do
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
        result = convert("- if true")
        expect(result).to eq("<% if true %>\n")
        expect(result).not_to include("<% end %>")
      end
    end

    context "HTML-style attributes" do
      it "converts basic HTML-style attributes" do
        expect(convert('%div(class="foo")')).to include('class="foo"')
      end

      it "converts multiple HTML-style attributes" do
        result = convert('%input(type="text" name="email")')
        expect(result).to include('type="text"')
        expect(result).to include('name="email"')
      end
    end

    context "multiline attributes" do
      it "converts hash attributes spanning multiple lines" do
        haml = "%div{class: \"foo\",\n     id: \"bar\"}"
        result = convert(haml)
        expect(result).to include('class="foo"')
        expect(result).to include('id="bar"')
      end
    end

    context "complex nested interpolation" do
      it "handles map with nested interpolation" do
        result = convert('%p #{items.map { |i| "#{i.name}" }.join(", ")}')
        expect(result).to include('<%= items.map { |i| "#{i.name}" }.join(", ") %>')
      end
    end

    context "object reference with prefix" do
      it "converts object reference with custom prefix" do
        result = convert("%tr[@item, :product]")
        expect(result).to include('<tr')
        expect(result).to include('"product_"')
      end
    end
  end
end
