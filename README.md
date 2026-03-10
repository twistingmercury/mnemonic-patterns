# mnemonic-patterns

Reusable AI engineering patterns for the Mnemonic memory system.

## Overview

`mnemonic-patterns` is a patterns repository that supplies domain knowledge to Mnemonic instances. It contains AI engineering patterns — reusable guidelines, code examples, and best practices — structured so that agents can discover and apply them when solving problems. Patterns are validated locally and loaded into a running Mnemonic instance via the Admin API.

## Prerequisites

- `yq` (mikefarah/yq v4+)
- `jq`
- `curl`
- A running Mnemonic instance (for loading)

## Pattern File Schema

Each pattern is a Markdown file with YAML frontmatter. See [docs/pattern-file-schema.md](docs/pattern-file-schema.md) for the full specification.

Required frontmatter fields:

- `name` — kebab-case machine identifier (e.g. `cobra-root-command-pattern`)
- `entity_type` — kebab-case category (e.g. `cli-pattern`, `best-practice`)
- `language` — one of: `agnostic go python dotnet shell typescript react sql cypher`
- `domain` — one of: `api-design backend frontend testing devops cli data-design documentation`
- `description` — non-empty, used for search and display

Optional fields:

- `agents` — array of agent names this pattern is relevant to
- `tags` — additional search keywords
- `version` — language/framework version target
- `related_patterns` — names of related patterns

Example frontmatter:

```yaml
---
name: cobra-root-command-pattern
entity_type: cli-pattern
language: go
domain: cli
description: Root command pattern with custom exit codes, error mapping, and help templates for Cobra CLIs
agents:
  - go-software-engineer
tags:
  - cobra
  - cli
  - go
---
```

## Validating Patterns

```bash
./scripts/validate.sh
```

Validate a custom directory:

```bash
./scripts/validate.sh --dir ./my-patterns
# or
PATTERNS_DIR=./my-patterns ./scripts/validate.sh
```

## Loading Patterns

```bash
./scripts/load.sh
```

`load.sh` runs validation first and aborts if any patterns fail.

Load to a custom Mnemonic server:

```bash
./scripts/load.sh --server http://myserver:8080
# or
MNEMONIC_BASE_URL=http://myserver:8080 ./scripts/load.sh
```

Load from a custom directory:

```bash
./scripts/load.sh --dir ./my-patterns
```

## Repository Structure

```
mnemonic-patterns/
├── README.md
├── docs/
│   └── pattern-file-schema.md
├── lib/
│   └── print.sh
├── scripts/
│   ├── validate.sh
│   └── load.sh
└── patterns/
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
