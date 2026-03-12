# Authoring Mnemonic Pattern Files

This guide teaches you how to write pattern files for the Mnemonic AI memory system. Each pattern is a Markdown file with YAML frontmatter, where decorated sections become searchable chunks in Mnemonic's vector index.

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

Context, motivation, and when to use this pattern. This section is never indexed, so put introductory material here. Explain the problem this pattern solves and why you should care.

[//]: pattern
## Section Title

Content that will be indexed as a searchable chunk. Code examples, named techniques, implementation details — anything useful to search for later.

[//]: pattern
## Another Section

More indexed content. Each decorated section becomes a standalone search result with this heading as the title.
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

| Good | Bad | Why |
|------|-----|-----|
| `cobra-root-command-pattern` | `root-cmd-go` | Descriptive, clear, searchable |
| `repository-timestamp-pattern` | `ts-pattern` | Full context, not cryptic |
| `error-handling-best-practice` | `error_handling_best_practice` | Kebab-case required |

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

| Good | Bad | Why |
|------|-----|-----|
| `cli-pattern` | `CLIPattern`, `cli_pattern` | Kebab-case, clear category |
| `go-pattern` | `golang-pattern` | Consistent with repository convention |
| `best-practice` | `goodpractice` | One-word categories are harder to search |

Choose a category that makes the pattern findable. If multiple categories apply, pick the primary one.

### `language` and `domain` — Search Axes

Language and domain are enums — you must choose from predefined lists. These help authors find patterns by technology and problem space.

**Language options:** agnostic, bash, c, cpp, csharp, cql, cypher, dart, delphi, docker, elixir, erlang, go, json, java, javascript, kotlin, lua, markdown, matlab, mql, objective-c, perl, php, plsql, powershell, python, r, react, ruby, rust, scala, shell, sql, swift, toml, tsql, typescript, visual-basic, yaml, zig

**Domain options:** api-design, backend, frontend, testing, devops, cli, data-design, documentation, data-access, security, shell-scripting, configuration, observability, source-management

**Examples:**

| name | language | domain | use case |
|------|----------|--------|----------|
| `cobra-root-command-pattern` | `go` | `cli` | Go CLI patterns |
| `repository-timestamp-pattern` | `go` | `data-access` | Database patterns in Go |
| `react-form-validation` | `react` | `frontend` | Frontend patterns |
| `sql-migration-naming` | `sql` | `data-design` | General SQL patterns |

Use `agnostic` for language-independent patterns. Pick the domain closest to the pattern's primary use — if a pattern spans multiple domains, choose the main one.

### `description` — Search Text

This is your elevator pitch. Authors see it in search results.

**Rules:**
- Non-empty, max 500 characters
- One sentence or two short sentences
- Mention what the pattern teaches and when to use it
- Make it specific: "how to do X with Y" not "X stuff"

**Examples:**

| Good | Bad | Why |
|------|-----|-----|
| `Root command pattern with custom exit codes, error mapping, custom help template with environment variables, and explicit command initialization` | `Cobra root command stuff` | Specific techniques, not vague |
| `Application-layer timestamp management pattern for created_at and updated_at columns in repositories, following storage-only database philosophy` | `Database timestamps` | States the philosophy, clear scope |
| `Configuration management with explicit config injection, environment variable overrides, and config precedence for Cobra CLIs` | `How to handle config` | Concrete techniques mentioned |

Write the description after drafting the pattern — you'll know what to emphasize then.

### `agents` — Who Should Know This

Optional. List agent roles this pattern is relevant to (e.g., `go-software-engineer`, `backend-developer`). Helps Mnemonic route patterns to the right team member.

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

This signals to readers whether the pattern applies to their codebase.

### `related_patterns` — Pattern Cross-References

Optional. List other pattern names this one relates to. Enrichment may add more.

```yaml
related_patterns:
  - cobra-configuration-pattern
  - error-handling-best-practice
```

Link to patterns you expect readers to want next. The system will build graph connections automatically.

## Writing the Body

### Structure: The `## Overview` Section

Every pattern must have a `## Overview` section as its first body section. This section is never indexed.

**What goes in Overview:**

- What problem does this pattern solve?
- When should you use it? When should you avoid it?
- Why is this the right approach?
- Any prerequisites or assumptions?

**What doesn't:**

- Code examples (those go in decorated sections)
- Step-by-step instructions (those go in decorated sections)
- Details that belong in a specific scenario (those go in H2/H3 decorated sections)

**Example Overview:**

```markdown
## Overview

This pattern demonstrates setting up a Cobra root command with custom exit codes, error-to-exit-code mapping, custom help templates, and explicit initialization. Use this when you need fine-grained control over CLI startup, error formatting, and exit codes for shell script integration. Avoid if your CLI is simple and doesn't need custom exit codes or specialized help text.
```

The Overview prepares readers for the details; it doesn't repeat them.

### Decorated Sections: Making Content Searchable

Any section you want to appear in Mnemonic search results must be preceded by a `[//]: pattern` decorator immediately before the heading.

```markdown
[//]: pattern
## Root Command Setup

This section will be indexed...
```

**Only decorated sections are stored in Mnemonic.** Everything else (including Overview) is discarded during chunking.

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

Too vague. "Introduction" doesn't describe the chunk. Readers won't search for "Introduction."

**Better example:**

```markdown
[//]: pattern
## Repository UPDATE Pattern

ALWAYS explicitly set `updated_at` in UPDATE statements:
...
```

Specific, searchable, stands alone.

### Naming Decorated Sections Well

Section headings become chunk titles in search results. Make them specific and actionable.

**Pattern:**

| Heading | Quality | Why |
|---------|---------|-----|
| `## Error to Exit Code Mapping` | Good | Specific technique, searchable |
| `## Root Command Setup` | Good | Clear scope, shows what section covers |
| `## Anti-Patterns` | Good | Readers specifically search for "what not to do" |
| `## Implementation` | Poor | Too vague, could be anything |
| `## Example` | Poor | Which example? Won't help search |
| `## Key Points` | Poor | Readers search for techniques, not summaries |

Name sections after the specific thing you're teaching: the technique, the scenario, the configuration option, or the anti-pattern.

### Granularity: H2 vs H3

Use **H2** (`##`) for top-level sections that stand alone. Use **H3** (`###`) for subsections within a broader topic.

**H2 example:**

```markdown
[//]: pattern
## Root Command Setup

Full section on setting up the root command...

[//]: pattern
## Custom Help Template with Environment Variables

Full section on help templates...
```

Each is independently valuable; each is decorated.

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

**Rule of thumb:** If a section could be found and used without reading the parent section, make it decorated. If it only makes sense after reading the parent, make it an H3 under the parent.

## The `[//]: pattern` Decorator

### Syntax

```markdown
[//]: pattern
```

Exact string, no trailing whitespace, on its own line immediately before a heading.

### Rules

1. **Placement:** On the line immediately before a heading (`#`, `##`, `###`, etc.)
2. **Exactness:** Must be exactly `[//]: pattern` with no variations
3. **Scope:** Everything from that heading until the next `[//]: pattern` decorator (or EOF) becomes one chunk
4. **Content outside:** Lines before the first decorator and between decorated sections are discarded

### What Gets Indexed

| Content | Indexed? |
|---------|----------|
| Decorated section heading and body | Yes |
| `## Overview` section | No — intentionally excluded |
| Undecorated sections | No |
| Intro text before first decorator | No |

### Common Mistakes

**Mistake 1: Decorating the Overview**

```markdown
[//]: pattern
## Overview

Don't do this — Overview is never indexed.
```

The validator will accept it (no rule forbids it), but it's wasted effort. Overview should never be decorated.

**Mistake 2: Forgetting decorators entirely**

```markdown
## Implementation

...

## Usage

...
```

These sections won't be indexed. Readers won't find them in search. Add `[//]: pattern` before each.

**Mistake 3: Decorating a section that only makes sense in context**

```markdown
[//]: pattern
## Key Points

- Point 1
- Point 2
- Point 3
```

If "Key Points" only summarizes the previous section and can't stand alone, don't decorate it. Move it into the previous section or create a dedicated technique section instead.

**Mistake 4: Decorating empty sections**

```markdown
[//]: pattern
## Notes

[Empty body]
```

Empty decorated sections are silently dropped during chunking. If you have nothing to say, remove the decorator and section entirely.

## Validating Your Work

Run the validator to catch errors before uploading:

```bash
./scripts/validate.sh
```

By default, this scans the `patterns/` directory. To validate a specific directory:

```bash
./scripts/validate.sh --dir docs/superpowers
```

**The validator checks:**

1. File is readable
2. YAML frontmatter is present and parseable
3. All required fields (name, entity_type, language, domain, description) are present and non-empty
4. `name` matches kebab-case format and is max 128 characters
5. `language` is one of the allowed enum values
6. `domain` is one of the allowed enum values
7. `entity_type` is in kebab-case
8. At least one `[//]: pattern` decorator is present
9. A `## Overview` section exists

If validation fails, the output tells you exactly what's wrong:

```
Invalid language 'golang' in cobra-root-command-pattern.md: must be one of: ... go ...
```

Fix the error and rerun validation.

## Complete Worked Example: Authoring a Pattern

Let's walk through authoring a real pattern: "PostgreSQL Connection Pool Pattern."

### Step 1: Define the Scope

What specific problem are we solving?

> Managing database connections in Go: how to configure a connection pool, set timeouts, and handle connection lifecycle in a production application.

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
- `name`: Specific, describes what it covers
- `entity_type`: It's a Go pattern
- `domain`: `data-access` is the primary domain
- `description`: States the three main topics (pool config, timeouts, lifecycle)
- `tags`: Framework and technology keywords
- `related_patterns`: Connects to other data-layer patterns

### Step 3: Draft Overview

```markdown
## Overview

PostgreSQL connection pooling is essential for production applications. This pattern covers configuring a connection pool with pgx, setting appropriate timeouts, and managing the connection lifecycle. Use this when building any Go application that connects to PostgreSQL. Avoid if you're prototyping with simple single-connection patterns — migrate to pooling before going to production.
```

**What this does:**
- Explains the problem (essential for production)
- Lists the three main topics (preview of what's coming)
- Tells readers when to use it (any production app)
- Tells readers when not to use it (early prototypes)

### Step 4: Identify Decorated Sections

What are the independently useful parts?

1. Basic pool configuration
2. Connection timeout settings
3. Query timeout settings
4. Connection lifecycle and cleanup
5. Testing with a pool
6. Anti-patterns (common mistakes)

### Step 5: Write Decorated Sections

```markdown
[//]: pattern
## Connection Pool Configuration

Basic setup with pgx:

```go
config, _ := pgx.ParseConfig(connString)
pool, _ := pgx.NewConnPool(ctx, connString, poolConfig)
defer pool.Close()
```

(explain each option)
```

```markdown
[//]: pattern
## Connection Timeout Settings

How to set connect and statement timeouts:

```go
config.ConnectTimeout = 10 * time.Second
config.StatementCacheMode = pgconn.PreparedStatementCacheModePrepare
```

(explain why and when)
```

And so on for each technique.

### Step 6: Validate

```bash
./scripts/validate.sh
```

If it passes, you're done. If it fails, fix the issues and rerun.

### Step 7: Review for Clarity

- Can each decorated section be understood on its own?
- Are the section headings specific and searchable?
- Does the Overview give readers the context they need?
- Are code examples clear and complete?

## Key Principles

**Be specific, not generic.** "Error Handling" is too broad. "Error to Exit Code Mapping" is specific and searchable.

**Stand-alone sections.** Each decorated section should be useful to someone who finds it in search, not someone reading the whole pattern.

**Code over prose.** Show working examples. Explain why, not just what.

**Frontmatter as metadata, not narrative.** Name, description, and tags help readers find the pattern. The body teaches them what to do.

**Validate early, iterate fast.** Run the validator after every major change. It catches structural errors before they become problems.

## Summary

1. **Choose values carefully:** name (kebab-case, specific), entity_type (category), language/domain (enum), description (searchable), tags (keywords)
2. **Structure the body:** Overview (non-indexed context), decorated sections (indexed techniques)
3. **Name sections specifically:** Readers search for "Error to Exit Code Mapping," not "Implementation"
4. **Decorate strategically:** Only sections that stand alone and are independently useful
5. **Validate:** Run `./scripts/validate.sh` to catch errors
6. **Iterate:** Review for clarity and consistency before merging

See [Pattern File Schema](pattern-file-schema.md) for the complete reference.
