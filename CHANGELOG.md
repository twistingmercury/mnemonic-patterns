# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-09-16

### Added

- Apache-2.0 LICENSE
- BATS test suite: `tests/validate.bats` and `tests/load.bats`
- `make test` target for running the BATS suite

### Changed

- Scripts relocated from `scripts/` directory to `install/`
- Shared library moved from `scripts/lib/print.sh` to `install/lib/print.sh`
- README documentation links updated to reference the mnemonic-docs repository: pattern schema now at `docs/reference/pattern-schema.md`, authoring guide now at `docs/guides/05-authoring-patterns.md`
- Pattern `related_patterns` frontmatter field format standardized to YAML list format
- Stale script paths corrected in pattern files
- `.gitignore`: removed rules for the deleted `docs/` tree; added `**/code_reviews/`

### Removed

- `docs/authoring-patterns.md` and `docs/pattern-file-schema.md` — these files have been moved to the [mnemonic-docs](https://github.com/twistingmercury/mnemonic-docs) repository
- `agent_associations` support removed from `install/load.sh`; the field is no longer derived from pattern frontmatter or sent in the payload POSTed to the Mnemonic Admin API
- `pattern-file-schema.md` dropped from the skip lists in `install/validate.sh` and `install/load.sh`, following the file's move to mnemonic-docs

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

[1.0.1]: https://github.com/twistingmercury/mnemonic-patterns/releases/tag/v1.0.1
[1.0.0]: https://github.com/twistingmercury/mnemonic-patterns/releases/tag/v1.0.0
