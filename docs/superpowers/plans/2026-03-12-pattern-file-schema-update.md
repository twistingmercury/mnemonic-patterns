# Pattern File Schema Update Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update `docs/pattern-file-schema.md` and `scripts/validate.sh` to accurately reflect the decorator-based chunking model.

**Architecture:** Surgical edits to two files. The schema doc gets updated enum tables, a rewritten Body Structure section, a new Chunking section, an updated Complete Example, and corrected Validation Rules. The validate script gets one grep replacement to check for `[//]: pattern` instead of H2 headings.

**Tech Stack:** Markdown, Bash, `yq`, `jq`

**Spec:** `docs/superpowers/specs/2026-03-12-pattern-file-schema-update-design.md`

---

## Chunk 1: Validate Baseline and Update `validate.sh`

### Task 1: Confirm baseline validation passes

**Files:**
- Read: `scripts/validate.sh`

- [ ] **Step 1: Run validation against all patterns**

```bash
./scripts/validate.sh
```

Expected: All pattern files pass. Note the exact summary line (e.g. "Passed: 65, Failed: 0"). This is your baseline — if anything changes after your edits, something went wrong.

---

### Task 2: Update `validate.sh` body structure check

**Files:**
- Modify: `scripts/validate.sh:191-196`

- [ ] **Step 1: Open `scripts/validate.sh` and locate the body structure check**

It looks like this (around line 191):

```bash
# --- Validate: body structure ---
# Check for at least one H2 section
if ! grep -q '^## ' "${file}"; then
    print::error "No H2 sections (## ) found in ${file}: at least one is required"
    errors=$((errors + 1))
fi
```

- [ ] **Step 2: Replace the H2 check with a decorator check**

Replace those 5 lines with:

```bash
# --- Validate: body structure ---
# Check for at least one [//]: pattern decorator
if ! grep -qF '[//]: pattern' "${file}"; then
    print::error "No '[//]: pattern' decorators found in ${file}: at least one decorated section is required"
    errors=$((errors + 1))
fi
```

Note: `grep -qF` uses fixed-string matching (not regex), which is correct here since `[//]: pattern` contains regex metacharacters.

- [ ] **Step 3: Run validation to confirm the same patterns still pass**

```bash
./scripts/validate.sh
```

Expected: Same summary as baseline (all patterns pass). If any file now fails, it is missing `[//]: pattern` decorators and needs to be investigated.

- [ ] **Step 4: Commit**

```bash
git add scripts/validate.sh
git commit -m "fix(validate): check for [//]: pattern decorators instead of H2 headings"
```

---

## Chunk 2: Update `docs/pattern-file-schema.md`

### Task 3: Update frontmatter enum tables

**Files:**
- Modify: `docs/pattern-file-schema.md`

The current `language` enum lists only 9 values. The current `domain` enum lists 8 values. Both need to be replaced with the values from `validate.sh`.

- [ ] **Step 1: Replace the `language` row in the Frontmatter Required Fields table**

Find this row:

```markdown
| `language`    | string | enum       | `agnostic`, `go`, `python`, `dotnet`, `shell`, `typescript`, `react`, `sql`, `cypher`           |
```

Replace with:

```markdown
| `language`    | string | enum       | `agnostic`, `bash`, `c`, `cpp`, `csharp`, `cql`, `cypher`, `dart`, `delphi`, `docker`, `elixir`, `erlang`, `go`, `json`, `java`, `javascript`, `kotlin`, `lua`, `markdown`, `matlab`, `mql`, `objective-c`, `perl`, `php`, `plsql`, `powershell`, `python`, `r`, `react`, `ruby`, `rust`, `scala`, `shell`, `sql`, `swift`, `toml`, `tsql`, `typescript`, `visual-basic`, `yaml`, `zig` |
```

Note: `dotnet` is intentionally absent — it was in the old doc but is not in `validate.sh`.

- [ ] **Step 2: Replace the `domain` row in the Frontmatter Required Fields table**

Find this row:

```markdown
| `domain`      | string | enum       | `api-design`, `backend`, `frontend`, `testing`, `devops`, `cli`, `data-design`, `documentation` |
```

Replace with:

```markdown
| `domain`      | string | enum       | `api-design`, `backend`, `frontend`, `testing`, `devops`, `cli`, `data-design`, `documentation`, `data-access`, `security`, `shell-scripting`, `configuration`, `observability`, `source-management` |
```

---

### Task 4: Update intro paragraph and Body Structure section

**Files:**
- Modify: `docs/pattern-file-schema.md`

- [ ] **Step 1: Update the intro paragraph**

Find this exact text (lines 5–7):

```
Pattern files are Markdown documents with YAML frontmatter. The body is divided into
sections using H2 headings (`##`). Each H2 section is stored as a separate searchable
chunk in Mnemonic. The H1 title is not chunked.
```

Replace with:

```
Pattern files are Markdown documents with YAML frontmatter. The body uses `[//]: pattern` decorators to mark which sections are indexed as searchable chunks in Mnemonic. Only decorated sections are stored — all other content, including the `## Overview` section, is discarded by the chunker. The H1 title is never indexed.
```

- [ ] **Step 2: Rewrite the `## Body Structure` section**

Find this exact block (lines 39–63):

```
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
```

Replace with the following (note: the inner code examples use 3-backtick fences — that is correct in the output file):

````
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
````

---

### Task 5: Add the new `## Chunking` section

**Files:**
- Modify: `docs/pattern-file-schema.md`

Insert a new `## Chunking` section immediately after `## Body Structure` and before `## Complete Example`.

- [ ] **Step 1: Insert the Chunking section**

Add the following after the Body Structure section:

````markdown
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

| Content | Indexed? |
| ------- | -------- |
| Decorated section (heading + body) | Yes |
| `## Overview` (undecorated) | No — intentionally excluded |
| Intro prose before first decorator | No |
| Section without a decorator | No |
| Empty decorated body (after trimming) | No — dropped silently |

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
````

---

### Task 6: Update the Complete Example

**Files:**
- Modify: `docs/pattern-file-schema.md`

The existing Complete Example shows a pattern file with no decorators. Add them.

- [ ] **Step 1: Add decorators to the Complete Example**

Find this exact block inside the fenced code block in `## Complete Example` (lines 92–107 of the file):

```
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

Replace with:

```
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

### Task 7: Update Validation Rules

**Files:**
- Modify: `docs/pattern-file-schema.md`

- [ ] **Step 1: Replace rule 9**

Find:

```markdown
9. At least one H2 section is present in the body.
```

Replace with:

```markdown
9. At least one `[//]: pattern` decorator is present in the body.
```

Rule 10 (`## Overview`) is unchanged.

- [ ] **Step 2: Run validation one final time to confirm everything is consistent**

```bash
./scripts/validate.sh
```

Expected: All patterns pass (same count as baseline from Task 1).

- [ ] **Step 3: Commit**

```bash
git add docs/pattern-file-schema.md
git commit -m "docs(schema): update pattern-file-schema.md for decorator-based chunking

- Replace H2-boundary chunking description with [//]: pattern decorator model
- Add dedicated Chunking section with syntax rules, table, and example
- Update language enum to 40 values matching validate.sh
- Remove dotnet (not in validate.sh)
- Update domain enum to 14 values matching validate.sh
- Update validation rule 9: decorator presence instead of H2 presence
- Update Complete Example with decorators"
```
