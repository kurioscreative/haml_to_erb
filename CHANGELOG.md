# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - Unreleased

### Added

- Initial release
- Convert HAML templates to ERB via `HamlToErb.convert`
- File and directory conversion with `convert_file` and `convert_directory`
- CLI tool `haml_to_erb` for batch conversion
- Optional ERB validation with Herb parser
- Support for tags, attributes, Ruby code blocks, filters, and interpolation
- Static attribute inlining via Prism parser
- Boolean and ARIA/data attribute handling
