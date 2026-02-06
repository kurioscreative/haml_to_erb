# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

## [0.1.0] - 2026-02-06

### Added

- Core conversion engine: HAML string → AST → ERB via `HamlToErb.convert`
- File and directory conversion with `convert_file` and `convert_directory`
- CLI tool `haml_to_erb` with `--check`, `--dry-run`, `--delete`, `--force`, `--version`, and `--debug` flags
- ERB validation via Herb parser (`validate`, `convert_and_validate`)
- Support for tags, attributes, Ruby code blocks, filters, and interpolation
- Static attribute inlining via Prism parser
- Boolean and ARIA/data attribute handling
- Haml 5, 6, and 7 compatibility
- GitHub Actions CI workflow

### Fixed

- Consistent HTML escaping for static attributes
- Odd-backslash logic for escaped quotes in interpolation
- Guard against missing line on HAML syntax errors
- CLI handles missing path argument gracefully
- CLI resolves paths with `File.expand_path`
- Warning when void elements have inline content or nested children
- Raise on unclosed string interpolation
- Safety measures for `--delete` flag (requires `--force` to skip confirmation)
