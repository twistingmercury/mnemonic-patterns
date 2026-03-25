# Pattern File Schema

This document defines the schema for Mnemonic pattern files.

Pattern files are Markdown documents with YAML frontmatter. The body uses `[//]: pattern` decorators to mark which sections are indexed as searchable chunks in Mnemonic. Only decorated sections are stored — all other content, including the `## Overview` section, is discarded by the chunker. The H1 title is never indexed.

---

## Frontmatter

### Required Fields

| Field         | Type   | Format     | Constraints                                                                                                                                                                                                                                                                                                                                                                             |
| ------------- | ------ | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`        | string | kebab-case | Machine identifier. Regex: `^[a-z][a-z0-9-]*$`. Max 128 characters.                                                                                                                                                                                                                                                                                                                     |
| `entity_type` | string | kebab-case | Category of pattern. e.g. `best-practice`, `cli-pattern`, `api-specification`                                                                                                                                                                                                                                                                                                           |
| `language`    | string | enum       | `agnostic`, `bash`, `c`, `cpp`, `csharp`, `cql`, `cypher`, `dart`, `delphi`, `docker`, `elixir`, `erlang`, `go`, `json`, `java`, `javascript`, `kotlin`, `lua`, `markdown`, `matlab`, `mql`, `objective-c`, `perl`, `php`, `plsql`, `powershell`, `python`, `r`, `react`, `ruby`, `rust`, `scala`, `shell`, `sql`, `swift`, `toml`, `tsql`, `typescript`, `visual-basic`, `yaml`, `zig` |
| `domain`      | string | enum       | `api-design`, `backend`, `frontend`, `testing`, `devops`, `cli`, `data-design`, `documentation`, `data-access`, `security`, `shell-scripting`, `configuration`, `observability`, `source-management`                                                                                                                                                                                    |
| `description` | string |            | Non-empty. Used for search and display.                                                                                                                                                                                                                                                                                                                             |

### Optional Fields

| Field              | Type            | Notes                                                                             |
| ------------------ | --------------- | --------------------------------------------------------------------------------- |
| `agents`           | array of string | Agent names this pattern is relevant to. Enrichment may add more.                 |
| `tags`             | array of string | Additional search keywords.                                                       |
| `version`          | string          | Version of the language, framework, or spec this pattern targets. e.g. `Go 1.21+` |
| `related_patterns` | array of string | Human-readable display titles of related patterns. Enrichment may add more.       |

### Unknown Fields

Additional frontmatter fields are allowed and ignored by validation. This permits
human-facing metadata (e.g. `author`, `created`) without failing validation.

---

## Body Structure

The body uses H1 for the file title and any number of H2/H3 sections for content.

### Required Sections

| Section       | Purpose                                       | Decorated?          |
| ------------- | --------------------------------------------- | ------------------- |
| `## Overview` | What the pattern is, when to use it, and why. | No — never index it |

### Decorated Sections

All sections intended to appear in search results must be preceded by `[//]: pattern` immediately before the heading. Sections without a decorator are silently discarded.

```markdown
[//]: pattern

## Implementation

Content that will be indexed...
```

H3 headings are supported the same as H2:

```markdown
[//]: pattern

### Named Sub-Technique

More content...
```

There are no prescribed section names beyond `## Overview`. Choose headings that make the content independently discoverable — each decorated section should make sense when returned as a standalone search result.

---

## Chunking

The `[//]: pattern` decorator controls which sections are stored in the Mnemonic vector index.

### Decorator Syntax

```
[//]: pattern
```

**Rules:**

- The decorator must be the exact string `[//]: pattern` with no trailing whitespace
- Place it on its own line immediately before a heading (`#`, `##`, `###`, etc.)
- Everything from that heading until the next `[//]: pattern` or end of file becomes the chunk body
- Lines outside decorated sections are **discarded** — they are never indexed

### What Gets Indexed vs. Discarded

| Content                               | Indexed?                    |
| ------------------------------------- | --------------------------- |
| Decorated section (heading + body)    | Yes                         |
| `## Overview` (undecorated)           | No — intentionally excluded |
| Intro prose before first decorator    | No                          |
| Section without a decorator           | No                          |
| Empty decorated body (after trimming) | No — dropped silently       |

### Example

```markdown
---
name: my-pattern
...
---

# My Pattern

## Overview

This section has no decorator — it will not be indexed.
Intro text, context, and motivation go here.

[//]: pattern

## Core Implementation

This section IS decorated — it will be indexed as a chunk with
title "Core Implementation" and this content as the body.

[//]: pattern

### Named Variant

This H3 section is also decorated and will be indexed separately.

## Notes

This section has no decorator — discarded, not indexed.
```

### When to Decorate

- **Do decorate:** any section with independently useful content — code examples, named techniques, configuration patterns, best practices
- **Do not decorate:** `## Overview`, summary sections, introductory prose, sections that only make sense in context of others

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
  - Cobra Root Command Pattern
  - Cobra Subcommand Pattern
---

# Cobra Configuration Pattern

## Overview

This pattern demonstrates configuration management for Cobra CLIs with explicit
config passing, environment variable overrides, and clear precedence rules.

[//]: pattern

## Implementation

...

[//]: pattern

## Example

...

[//]: pattern

## Key Patterns

...
```

---

## Validation Rules

`install/validate.sh` enforces the following:

1. File exists and is readable.
2. YAML frontmatter is present and parseable.
3. All required frontmatter fields are present and non-empty.
4. `name` matches `^[a-z][a-z0-9-]*$`.
5. `language` is one of the allowed enum values.
6. `domain` is one of the allowed enum values.
7. `entity_type` uses kebab-case.
8. `description` is non-empty.
9. At least one `[//]: pattern` decorator is present in the body.
10. The `## Overview` section is present.

Unknown frontmatter fields are ignored.
