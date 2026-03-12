# Authoring Mnemonic Pattern Files

This guide teaches you how to write pattern files for the Mnemonic AI memory system. Each pattern is a Markdown file with YAML frontmatter. Decorated sections become searchable chunks in Mnemonic's vector index.

For a complete reference of all fields and rules, see [Pattern File Schema](pattern-file-schema.md).

## Quick Start

Copy this template, fill in your content, and validate with `./scripts/validate.sh`:

```markdown
---
name: your-pattern-name
entity_type: pattern-category
language: go
domain: backend
description: One sentence describing what this pattern teaches and when to use it. Keep under 500 characters.
tags:
  - keyword1
  - keyword2
version: Go 1.21+
related_patterns:
  - related-pattern-name
---

# Your Pattern Name

## Overview

Context, motivation, and when to use this pattern. Overview is never indexed, so place introductory material here. Explain the problem this pattern solves and why it matters.

[//]: pattern

## Section Title

Content indexed as a searchable chunk. Includes code examples, named techniques, implementation details — anything useful to retrieve later.

[//]: pattern

## Another Section

More indexed content. Each decorated section becomes a standalone search result, with the heading as the title.
```

Run validation:

```bash
./scripts/validate.sh
```

A pattern is valid when it has frontmatter, at least one decorated section, and a `## Overview`.

## Frontmatter: Choosing Good Values

### `name` — Machine Identifier

Keep it descriptive but short. Filenames match the pattern name.

**Rules:**

- Kebab-case only: lowercase letters, numbers, hyphens
- No spaces, underscores, or special characters
- Max 128 characters (rarely needed)
- File is named `<name>.md`

**Examples:**

| Good                           | Bad                            | Why                            |
| ------------------------------ | ------------------------------ | ------------------------------ |
| `cobra-root-command-pattern`   | `root-cmd-go`                  | Descriptive, clear, searchable |
| `repository-timestamp-pattern` | `ts-pattern`                   | Full context, not cryptic      |
| `error-handling-best-practice` | `error_handling_best_practice` | Kebab-case required            |

### `entity_type` — Pattern Category

Classify what kind of pattern this is. Use kebab-case.

**Common values:**

- `cli-pattern` — Command-line interface patterns
- `go-pattern` — Go language patterns
- `best-practice` — General best practices
- `api-specification` — API design specs
- `architectural-pattern` — System architecture
- `data-pattern` — Database/data design

**Examples:**

| Good            | Bad                         | Why                                      |
| --------------- | --------------------------- | ---------------------------------------- |
| `cli-pattern`   | `CLIPattern`, `cli_pattern` | Kebab-case, clear category               |
| `go-pattern`    | `golang-pattern`            | Consistent with repository convention    |
| `best-practice` | `goodpractice`              | One-word categories are harder to search |

Choose the category that makes the pattern most findable. If multiple categories apply, pick the primary domain.

### `language` and `domain` — Search Axes

Language and domain are enums — you must choose from predefined lists. These help authors find patterns by technology and problem space.

**Language options:** agnostic, bash, c, cpp, csharp, cql, cypher, dart, delphi, docker, elixir, erlang, go, json, java, javascript, kotlin, lua, markdown, matlab, mql, objective-c, perl, php, plsql, powershell, python, r, react, ruby, rust, scala, shell, sql, swift, toml, tsql, typescript, visual-basic, yaml, zig

**Domain options:** api-design, backend, frontend, testing, devops, cli, data-design, documentation, data-access, security, shell-scripting, configuration, observability, source-management

**Examples:**

| name                           | language | domain        | use case                |
| ------------------------------ | -------- | ------------- | ----------------------- |
| `cobra-root-command-pattern`   | `go`     | `cli`         | Go CLI patterns         |
| `repository-timestamp-pattern` | `go`     | `data-access` | Database patterns in Go |
| `react-form-validation`        | `react`  | `frontend`    | Frontend patterns       |
| `sql-migration-naming`         | `sql`    | `data-design` | General SQL patterns    |

Use `agnostic` for language-independent patterns. Pick the domain closest to the pattern's primary use.

### `description` — Search Text

Your elevator pitch. Authors see it in search results.

**Rules:**

- Non-empty, max 500 characters
- One sentence or two short sentences
- Mention what the pattern teaches and when to use it
- Make it specific: "how to do X with Y" not "X stuff"

**Examples:**

| Good                                                                                                                                               | Bad                        | Why                                |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- | ---------------------------------- |
| `Root command pattern with custom exit codes, error mapping, custom help template with environment variables, and explicit command initialization` | `Cobra root command stuff` | Specific techniques, not vague     |
| `Application-layer timestamp management pattern for created_at and updated_at columns in repositories, following storage-only database philosophy` | `Database timestamps`      | States the philosophy, clear scope |
| `Configuration management with explicit config injection, environment variable overrides, and config precedence for Cobra CLIs`                    | `How to handle config`     | Concrete techniques mentioned      |

Write the description after drafting the pattern — you'll know what to emphasize then.

### `agents` — Who Should Know This

Optional. List agent roles this pattern is relevant to (e.g., `go-software-engineer`, `backend-developer`). Routes patterns to the appropriate team.

```yaml
agents:
  - go-software-engineer
  - backend-developer
```

### `tags` — Extra Keywords

Optional. Add domain-specific keywords for better search discoverability.

```yaml
tags:
  - cobra
  - cli
  - error-handling
  - exit-codes
```

Use tags for framework names, specific libraries, or problem space keywords that don't fit in `name` or `description`.

### `version` — Target Version

Optional. Specify which version of a language, framework, or spec the pattern targets.

```yaml
version: Go 1.21+
version: PostgreSQL 14+
version: React 18.x
```

Readers use this to judge whether the pattern applies to their codebase.

### `related_patterns` — Pattern Cross-References

Optional. List other pattern names this one relates to. Enrichment may add more.

```yaml
related_patterns:
  - cobra-configuration-pattern
  - error-handling-best-practice
```

Link to patterns readers will likely want next. The system builds graph connections automatically.

## Writing the Body

### Structure: The `## Overview` Section

Every pattern must have a `## Overview` section as its first body section. This section is never indexed.

**Include:**

- The problem this pattern solves
- When to use it and when to avoid it
- Why this is the right approach
- Prerequisites and assumptions

**Exclude:**

- Code examples (put those in decorated sections)
- Step-by-step instructions (put those in decorated sections)
- Details belonging to specific scenarios (put those in H2/H3 decorated sections)

**Example Overview:**

```markdown
## Overview

This pattern demonstrates setting up a Cobra root command with custom exit codes, error-to-exit-code mapping, custom help templates, and explicit initialization. Use this when you need fine-grained control over CLI startup, error formatting, and exit codes for shell script integration. Avoid if your CLI is simple and doesn't need custom exit codes or specialized help text.
```

Overview introduces context; don't repeat the details.

### Decorated Sections: Making Content Searchable

Any section you want to appear in Mnemonic search results must be preceded by a `[//]: pattern` decorator immediately before the heading.

```markdown
[//]: pattern

## Root Command Setup

This section will be indexed...
```

**Only decorated sections are stored in Mnemonic.** Everything else—including Overview—is discarded during chunking.

### Choosing What to Decorate

**Decorate sections that are independently useful:**

- Named implementation techniques (`## Error to Exit Code Mapping`)
- Code examples with explanations (`## Using sqlx for Cleaner Code`)
- Configuration patterns (`## Persistent Flags Pattern`)
- Anti-patterns and what to avoid (`## Anti-Patterns`)
- Testing strategies (`## Exit Code Testing`)
- Specific scenarios (`## Batch Update Pattern`)

**Don't decorate:**

- `## Overview` (already excluded)
- Intro text or transition prose
- Sections that only make sense in context of another section
- Empty sections

**Bad decoration example:**

```markdown
[//]: pattern

## Introduction

This pattern is about timestamps...
```

"Introduction" is too vague to be searchable. Readers don't search for "Introduction."

**Good example:**

```markdown
[//]: pattern

## Repository UPDATE Pattern

Always explicitly set `updated_at` in UPDATE statements:
...
```

Specific, searchable, stands independently.

### Naming Decorated Sections

Section headings become chunk titles in search results. Make them specific and actionable.

**Pattern:**

| Heading                         | Quality | Why                                              |
| ------------------------------- | ------- | ------------------------------------------------ |
| `## Error to Exit Code Mapping` | Good    | Specific technique, searchable                   |
| `## Root Command Setup`         | Good    | Clear scope, shows what section covers           |
| `## Anti-Patterns`              | Good    | Readers specifically search for "what not to do" |
| `## Implementation`             | Poor    | Too vague, could be anything                     |
| `## Example`                    | Poor    | Which example? Won't help search                 |
| `## Key Points`                 | Poor    | Readers search for techniques, not summaries     |

Name sections after the specific thing you teach: the technique, the scenario, the configuration option, or the anti-pattern.

### Granularity: H2 vs H3

Use **H2** (`##`) for top-level sections that stand alone. Use **H3** (`###`) for subsections under a broader topic.

**H2 example:**

```markdown
[//]: pattern

## Root Command Setup

Full section on setting up the root command...

[//]: pattern

## Custom Help Template with Environment Variables

Full section on help templates...
```

Each stands alone and is decorated.

**H3 example:**

```markdown
[//]: pattern

## Repository Pattern

This is the top-level section.

### Database Schema

Details about the schema within this pattern...

### Repository INSERT Pattern

Details about inserts within this pattern...
```

The H2 is a container; H2 and H3 sections are decorated separately if each is independently useful.

**Rule of thumb:** Decorate sections that are independently useful. If a section only makes sense after reading the parent, make it an H3 under the parent instead.

## The `[//]: pattern` Decorator

### Syntax

```markdown
[//]: pattern
```

Use this exact string with no trailing whitespace. Place it on its own line immediately before a heading.

### Rules

1. **Placement:** Put it on the line immediately before a heading (`#`, `##`, `###`, etc.)
2. **Exactness:** Use exactly `[//]: pattern` with no variations
3. **Scope:** Everything from that heading to the next `[//]: pattern` decorator (or EOF) becomes one chunk
4. **Exclusions:** Lines before the first decorator and between decorated sections are not indexed

### What Gets Indexed

| Content                            | Indexed?                    |
| ---------------------------------- | --------------------------- |
| Decorated section heading and body | Yes                         |
| `## Overview` section              | No — intentionally excluded |
| Undecorated sections               | No                          |
| Intro text before first decorator  | No                          |

### Common Mistakes

**Mistake 1: Decorating the Overview**

```markdown
[//]: pattern

## Overview

Don't do this — Overview is never indexed.
```

The validator accepts it (no rule forbids it), but it wastes effort. Never decorate Overview.

**Mistake 2: Forgetting decorators**

```markdown
## Implementation

...

## Usage

...
```

These sections won't be indexed and readers won't find them in search. Add `[//]: pattern` before each.

**Mistake 3: Decorating context-dependent sections**

```markdown
[//]: pattern

## Key Points

- Point 1
- Point 2
- Point 3
```

If "Key Points" only summarizes the prior section and cannot stand alone, don't decorate it. Merge it into the prior section or create a dedicated technique section.

**Mistake 4: Decorating empty sections**

```markdown
[//]: pattern

## Notes

[Empty body]
```

Chunking silently drops empty decorated sections. If you have nothing to say, remove the decorator and section.

## Validating Your Work

Run the validator to catch errors before uploading:

```bash
./scripts/validate.sh
```

By default, this scans the `patterns/` directory. To validate a specific directory:

```bash
./scripts/validate.sh --dir docs/superpowers
```

**The validator verifies:**

1. File is readable
2. YAML frontmatter is present and valid
3. Required fields are present and non-empty (name, entity_type, language, domain, description)
4. `name` uses kebab-case and is max 128 characters
5. `language` is a valid enum value
6. `domain` is a valid enum value
7. `entity_type` uses kebab-case
8. At least one `[//]: pattern` decorator exists
9. A `## Overview` section exists

If validation fails, read the error message:

```
Invalid language 'golang' in cobra-root-command-pattern.md: must be one of: ... go ...
```

Fix the issue and rerun validation.

## Complete Worked Example: Authoring a Pattern

Let's walk through authoring a real pattern: "PostgreSQL Connection Pool Pattern."

### Step 1: Define the Scope

What specific problem does this pattern solve?

> Managing database connections in Go: configuring a connection pool, setting timeouts, and handling connection lifecycle in production.

### Step 2: Choose Frontmatter

```yaml
name: postgresql-connection-pool-pattern
entity_type: go-pattern
language: go
domain: data-access
description: Connection pool configuration, timeout management, and lifecycle handling for PostgreSQL databases in Go applications
tags:
  - postgresql
  - database
  - connection-pool
  - sqlc
  - pgx
version: Go 1.21+, PostgreSQL 14+
related_patterns:
  - repository-timestamp-pattern
  - sql-migration-pattern
```

**Decisions:**

- `name`: Specific and descriptive
- `entity_type`: Classify as a Go pattern
- `domain`: `data-access` is primary
- `description`: States three main topics (pool config, timeouts, lifecycle)
- `tags`: Include framework and technology keywords
- `related_patterns`: Connect to other data-layer patterns

### Step 3: Draft Overview

```markdown
## Overview

PostgreSQL connection pooling is essential for production applications. This pattern covers configuring a connection pool with pgx, setting appropriate timeouts, and managing the connection lifecycle. Use this when building any Go application connecting to PostgreSQL. Avoid if you're prototyping with simple single-connection patterns — migrate to pooling before production.
```

**What this achieves:**

- Explains the problem (essential for production)
- Previews three main topics
- States when to use it (any production app)
- States when to avoid it (early prototypes)

### Step 4: Identify Decorated Sections

What parts are independently useful?

1. Basic pool configuration
2. Connection timeout settings
3. Query timeout settings
4. Connection lifecycle and cleanup
5. Testing with a pool
6. Anti-patterns and common mistakes

### Step 5: Write Decorated Sections

````markdown
[//]: pattern

## Connection Pool Configuration

Basic setup with pgx:

```go
config, _ := pgx.ParseConfig(connString)
pool, _ := pgx.NewConnPool(ctx, connString, poolConfig)
defer pool.Close()
```
````

(explain each option)

````

```markdown
[//]: pattern
## Connection Timeout Settings

How to set connect and statement timeouts:

```go
config.ConnectTimeout = 10 * time.Second
config.StatementCacheMode = pgconn.PreparedStatementCacheModePrepare
````

(explain why and when)

````

And so on for each technique.

### Step 6: Validate

```bash
./scripts/validate.sh
```

If it passes, you're done. If it fails, fix the issues and rerun.

### Step 7: Review for Clarity

- Does each decorated section stand alone?
- Are section headings specific and searchable?
- Does Overview provide necessary context?
- Are code examples clear and complete?

## Key Principles

**Be specific.** "Error Handling" is too broad. "Error to Exit Code Mapping" is specific and searchable.

**Write standalone sections.** Each decorated section should help someone who finds it in search—not just someone reading the whole pattern.

**Show code first.** Provide working examples and explain why, not just what.

**Frontmatter as metadata.** Name, description, and tags make the pattern findable. The body teaches what to do.

**Validate early.** Run the validator after each major change to catch structural errors before they compound.

## Summary

1. **Choose frontmatter carefully:** name (kebab-case, specific), entity_type (category), language/domain (enum), description (searchable), tags (keywords)
2. **Structure the body:** Overview (context only), decorated sections (indexed techniques)
3. **Name sections specifically:** Readers search for "Error to Exit Code Mapping," not "Implementation"
4. **Decorate strategically:** Only sections that stand alone
5. **Validate:** Run `./scripts/validate.sh` to catch errors
6. **Iterate:** Review for clarity before merging

See [Pattern File Schema](pattern-file-schema.md) for the complete reference.
