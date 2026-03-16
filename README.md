# mnemonic-patterns

> **Maturity Level**: Basic
>
> - **Emerging**: Prototype, not production-ready, expect breaking changes
> - **Basic**: Production-ready but actively evolving, expect minor version changes
> - **Mature**: Stable, battle-tested, changes are rare

Reusable AI engineering patterns for the Mnemonic memory system. Each pattern is a Markdown file with YAML frontmatter that agents can discover and apply when solving problems.

## Table of Contents

- [Usage](#usage)
- [How it works](#how-it-works)
- [Key Considerations](#key-considerations)
- [Development Considerations](#development-considerations)
- [Versioning](#versioning)

## Usage

Validate all patterns:

```bash
make validate
# or
./scripts/validate.sh
```

Load patterns into a running Mnemonic instance:

```bash
make load
# or
./scripts/load.sh
```

Load to a custom server or directory:

```bash
./scripts/load.sh --server http://myserver:8080
./scripts/load.sh --dir ./my-patterns
```

## How it works

Each pattern file lives under `patterns/` as a Markdown file with YAML frontmatter. Sections preceded by a `[//]: pattern` decorator are chunked and indexed into Mnemonic's vector store, making them retrievable by agents during problem-solving.

`validate.sh` checks frontmatter schema for all patterns. `load.sh` runs validation first, then POSTs each pattern to the Mnemonic Admin API.

**Repository layout:**

```
patterns/
├── api-patterns/
├── bats-patterns/
├── cli-patterns/
├── data-patterns/
├── devops-patterns/
├── e2e-patterns/
├── engineering-guidelines/
├── go-patterns/
└── shell-script-patterns/
```

## Key Considerations

- **Required frontmatter fields:** `name` (kebab-case), `entity_type` (kebab-case), `language` (enum), `domain` (enum), `description` (non-empty, ≤500 chars)
- **Indexed content only:** Sections must have a `[//]: pattern` decorator to be stored in Mnemonic; `## Overview` is never indexed
- **Loading requires a running Mnemonic instance** — `load.sh` uses `MNEMONIC_BASE_URL` (default: `http://localhost:8080`) or `--server`

See [docs/pattern-file-schema.md](docs/pattern-file-schema.md) for the complete field reference and [docs/authoring-patterns.md](docs/authoring-patterns.md) for a step-by-step authoring guide.

## Development Considerations

### Prerequisites

- `yq` (mikefarah/yq v4+)
- `jq`
- `curl`
- A running Mnemonic instance (for loading)

### Quick Start

```bash
# Validate all patterns
make validate

# Add a new pattern, then validate
cp patterns/go-patterns/repository-timestamp-pattern.md patterns/go-patterns/my-pattern.md
# edit my-pattern.md
./scripts/validate.sh
```

### Testing

Run the validator against patterns before committing:

```bash
make validate
```

To validate a specific directory:

```bash
./scripts/validate.sh --dir ./my-patterns
```

### Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/).

Version is determined from git tags:

```bash
git describe --tags --always
```

Current version: `v0.0.1`
