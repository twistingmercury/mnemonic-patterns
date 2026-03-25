# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-17

### Added

**Pattern Library:**
- API patterns for HTTP API design
- BATS testing patterns
- CLI patterns for command-line tool development
- Data patterns for data modeling and schema design
- DevOps patterns for deployment and infrastructure
- E2E testing patterns
- Engineering guidelines for general best practices
- Go patterns for Go service development
- Shell script patterns for shell scripting

**Tools:**
- `install/validate.sh` — validates pattern frontmatter against schema
- `install/load.sh` — validates and loads patterns into Mnemonic Admin API
- `install/lib/print.sh` — shared print utilities for install scripts
- Makefile with `validate`, `load`, and `test` targets

**Testing:**
- BATS test suite covering validation and loading logic

**Documentation:**
- `docs/pattern-file-schema.md` — frontmatter field reference
- `docs/authoring-patterns.md` — pattern authoring guide

**Features:**
- Decorator-based chunking with `[//]: pattern` markers
- Only decorated sections are indexed into Mnemonic vector store
- YAML frontmatter validation for all patterns
- Support for loading to custom Mnemonic instance via `--server` flag

[1.0.0]: https://github.com/twistingmercury/mnemonic-patterns/releases/tag/v1.0.0
