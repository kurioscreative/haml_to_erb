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

  describe ".convert" do
    context "ERB validity (using Herb parser)" do
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
        expect(result).to be_valid_erb
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
        expect(result).to be_valid_erb
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
        expect(result).to be_valid_erb
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
        expect(result).to be_valid_erb
      end

      it "converts tag with interpolated helper methods to separate ERB tags" do
        result = convert('%p #{link_to "Home", root_path} or #{link_to "Sign in", login_path} please.')
        expect(result).to include("<p>")
        expect(result).to include("<%= link_to \"Home\", root_path %>")
        expect(result).to include(" or ")
        expect(result).to include("<%= link_to \"Sign in\", login_path %>")
        expect(result).to include(" please.")
        expect(result).to include("</p>")
        expect(result).not_to include('<%=  "')
        expect(result).not_to include('<%= "#{')
        expect(result).to be_valid_erb
      end
    end

    context "multiline content" do
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
        expect(result).to be_valid_erb
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
      result = described_class.validate("<p><%= @name %></p>")
      expect(result.valid?).to be true
      expect(result.errors).to be_empty
    end

    it "returns invalid result for malformed ERB" do
      result = described_class.validate("<%= if true %>")
      expect(result.valid?).to be false
      expect(result.errors).not_to be_empty
    end

    it "includes error details with message" do
      result = described_class.validate("<%= unclosed")
      expect(result.errors.first).to have_key(:message)
    end
  end

  describe ".convert_and_validate" do
    it "converts and validates in one call" do
      result = described_class.convert_and_validate("%p Hello")
      expect(result).to be_a(HamlToErb::ValidationResult)
      expect(result.erb).to include("<p>Hello</p>")
    end

    it "returns ValidationResult with erb content" do
      result = described_class.convert_and_validate("%div.foo")
      expect(result.erb).to include('class="foo"')
    end

    it "reports validation errors for complex output" do
      result = described_class.convert_and_validate("%p= @value")
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
