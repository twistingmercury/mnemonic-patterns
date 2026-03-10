# Pattern File Schema

This document defines the schema for Mnemonic pattern files used with `mnemctl`.

Pattern files are Markdown documents with YAML frontmatter. The body is divided into
sections using H2 headings (`##`). Each H2 section is stored as a separate searchable
chunk in Mnemonic. The H1 title is not chunked.

---

## Frontmatter

### Required Fields

| Field         | Type   | Format     | Constraints                                                                                     |
| ------------- | ------ | ---------- | ----------------------------------------------------------------------------------------------- |
| `name`        | string | kebab-case | Machine identifier. Regex: `^[a-z][a-z0-9-]*$`. Max 128 characters.                             |
| `entity_type` | string | kebab-case | Category of pattern. e.g. `best-practice`, `cli-pattern`, `api-specification`                   |
| `language`    | string | enum       | `agnostic`, `go`, `python`, `dotnet`, `shell`, `typescript`, `react`, `sql`, `cypher`           |
| `domain`      | string | enum       | `api-design`, `backend`, `frontend`, `testing`, `devops`, `cli`, `data-design`, `documentation` |
| `description` | string |            | Non-empty. Used for search and display. Max 500 characters.                                     |

### Optional Fields

| Field              | Type            | Notes                                                                             |
| ------------------ | --------------- | --------------------------------------------------------------------------------- |
| `agents`           | array of string | Agent names this pattern is relevant to. Enrichment may add more.                 |
| `tags`             | array of string | Additional search keywords.                                                       |
| `version`          | string          | Version of the language, framework, or spec this pattern targets. e.g. `Go 1.21+` |
| `related_patterns` | array of string | Names of related patterns by `name` field. Enrichment may add more.               |

### Unknown Fields

Additional frontmatter fields are allowed and ignored by validation. This permits
human-facing metadata (e.g. `author`, `created`) without failing validation.

---

## Body Structure

The body uses H2 headings to define chunk boundaries. Each H2 section becomes a
separate searchable chunk stored in Mnemonic.

### Required Sections

| Section       | Purpose                                       |
| ------------- | --------------------------------------------- |
| `## Overview` | What the pattern is, when to use it, and why. |

### Recommended Sections

These sections are not required but improve searchability and usefulness:

| Section             | Purpose                               |
| ------------------- | ------------------------------------- |
| `## Implementation` | Core implementation code or approach. |
| `## Example`        | Concrete usage example.               |
| `## Key Patterns`   | Summary of the key takeaways.         |

Additional H2 sections are allowed. The author controls chunking by how they
organize headings — more specific sections produce more targeted search results.

> **Note:** A file with no H2 headings will produce no chunks and fail validation.

---

## Complete Example

```markdown
---
name: cobra-configuration-pattern
entity_type: cli-pattern
language: go
domain: cli
description: Configuration management with explicit config injection, environment variable overrides, and config precedence for Cobra CLIs
agents:
  - go-software-engineer
tags:
  - cobra
  - cli
  - configuration
  - go
  - environment-variables
version: Go 1.21+
related_patterns:
  - cobra-root-command-pattern
  - cobra-subcommand-pattern
---

# Cobra Configuration Pattern

## Overview

This pattern demonstrates configuration management for Cobra CLIs with explicit
config passing, environment variable overrides, and clear precedence rules.

## Implementation

...

## Example

...

## Key Patterns

...
```

---

## Validation Rules

`mnemctl pattern validate` enforces the following:

1. File exists and is readable.
2. YAML frontmatter is present and parseable.
3. All required frontmatter fields are present and non-empty.
4. `name` matches `^[a-z][a-z0-9-]*$`.
5. `language` is one of the allowed enum values.
6. `domain` is one of the allowed enum values.
7. `entity_type` uses kebab-case.
8. `description` is non-empty.
9. At least one H2 section is present in the body.
10. The `## Overview` section is present.

Unknown frontmatter fields are ignored.
