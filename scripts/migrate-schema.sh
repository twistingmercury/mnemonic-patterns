#!/usr/bin/env bash
# migrate-schema.sh
#
# Migrates pattern files from the old Cognee schema to the new Mnemonic schema.
#
# Usage:
#   ./migrate-schema.sh
#
# Environment variables (optional overrides):
#   SOURCE_DIR   - path to the source patterns root
#                  default: /Users/doublej/dev/claudecode/patterns
#   DEST_DIR     - path to the destination patterns root
#                  default: /Users/doublej/dev/mnemonic-patterns/patterns
#
# Files skipped:
#   README.md
#   PATTERN-METADATA-SCHEMA.md

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SOURCE_DIR="${SOURCE_DIR:-/Users/doublej/dev/claudecode/patterns}"
DEST_DIR="${DEST_DIR:-/Users/doublej/dev/mnemonic-patterns/patterns}"

readonly SOURCE_DIR DEST_DIR

SUBDIRS=(
    api-patterns
    bats-patterns
    cli-patterns
    data-patterns
    devops-patterns
    e2e-patterns
    engineering-guidelines
    go-patterns
    shell-script-patterns
)

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

validate_environment() {
    if [ ! -d "${SOURCE_DIR}" ]; then
        printf 'ERROR: source directory does not exist: %s\n' "${SOURCE_DIR}" >&2
        exit 1
    fi

    if ! command -v python3 > /dev/null 2>&1; then
        printf 'ERROR: python3 is required but not found in PATH\n' >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Frontmatter transformation (Python3 — no external deps)
# ---------------------------------------------------------------------------

# transform_file <src_path> <dest_path>
#
# Copies a markdown file to the destination, transforming YAML frontmatter:
#   - entity_name -> name (kebab-case slug)
#   - entity_type -> lowercase kebab-case (already kebab or spaces replaced)
#   - tags        -> all lowercase
#   - entity_name field is removed
#   - all other fields are preserved unchanged
transform_file() {
    # src and dest are passed via _MIGRATE_SRC / _MIGRATE_DEST env vars
    # (set by the caller) so that the Python heredoc can read them.
    local dest_path="${2}"
    local dest_dir

    dest_dir="$(dirname "${dest_path}")"
    mkdir -p "${dest_dir}"

    python3 << 'PYEOF'
import sys
import re
import os

src_path = os.environ.get('_MIGRATE_SRC')
dest_path = os.environ.get('_MIGRATE_DEST')

with open(src_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Split into frontmatter + body.
# Frontmatter is delimited by --- on its own line at start and end.
fm_match = re.match(r'^---\n(.*?)\n---\n(.*)', content, re.DOTALL)
if not fm_match:
    # No frontmatter — copy as-is.
    with open(dest_path, 'w', encoding='utf-8') as f:
        f.write(content)
    sys.exit(0)

fm_raw = fm_match.group(1)
body   = fm_match.group(2)

# ---- Parse frontmatter lines preserving order and structure ----

def make_slug(text):
    """Convert entity_name to a kebab-case slug."""
    slug = text.lower()
    slug = re.sub(r'[\s_]+', '-', slug)
    slug = re.sub(r'[^a-z0-9-]', '', slug)
    slug = re.sub(r'-{2,}', '-', slug)
    slug = slug.strip('-')
    slug = slug[:128]
    return slug

def kebab(text):
    """Convert entity_type to lowercase kebab-case."""
    out = text.lower()
    out = re.sub(r'\s+', '-', out)
    out = re.sub(r'-{2,}', '-', out)
    return out.strip('-')

# We process line-by-line to preserve comments, order, and multi-line values.
lines = fm_raw.split('\n')
output_lines = []
entity_name_value = None

i = 0
while i < len(lines):
    line = lines[i]

    # entity_name: capture value, do not emit line
    if re.match(r'^entity_name\s*:', line):
        m = re.match(r'^entity_name\s*:\s*(.*)', line)
        entity_name_value = m.group(1).strip() if m else ''
        i += 1
        continue

    # entity_type: emit transformed value
    if re.match(r'^entity_type\s*:', line):
        m = re.match(r'^entity_type\s*:\s*(.*)', line)
        raw_type = m.group(1).strip() if m else ''
        output_lines.append('entity_type: ' + kebab(raw_type))
        i += 1
        continue

    # tags: lowercase each tag item
    if re.match(r'^tags\s*:', line):
        output_lines.append('tags:')
        i += 1
        # Consume following tag list items (lines starting with '  - ')
        while i < len(lines) and re.match(r'^\s+- ', lines[i]):
            tag_m = re.match(r'^(\s+- )(.*)', lines[i])
            if tag_m:
                output_lines.append(tag_m.group(1) + tag_m.group(2).strip().lower())
            else:
                output_lines.append(lines[i])
            i += 1
        continue

    output_lines.append(line)
    i += 1

# Prepend the derived name field (first field in output)
slug = make_slug(entity_name_value) if entity_name_value is not None else ''
name_line = 'name: ' + slug

new_fm = '\n'.join([name_line] + output_lines)
new_content = '---\n' + new_fm + '\n---\n' + body

with open(dest_path, 'w', encoding='utf-8') as f:
    f.write(new_content)
PYEOF
}

# skip_file <filename>
# Returns 0 (true) if the file should be skipped.
skip_file() {
    local filename="${1}"
    case "${filename}" in
        README.md | PATTERN-METADATA-SCHEMA.md)
            return 0
            ;;
    esac
    return 1
}

# ---------------------------------------------------------------------------
# Migration
# ---------------------------------------------------------------------------

migrate_directory() {
    local subdir="${1}"
    local src_subdir="${SOURCE_DIR}/${subdir}"

    if [ ! -d "${src_subdir}" ]; then
        printf 'WARN: source subdirectory not found, skipping: %s\n' "${src_subdir}"
        return 0
    fi

    printf 'Migrating: %s\n' "${subdir}"

    # Find all .md files under the subdir.
    while IFS= read -r -d '' src_file; do
        local filename
        filename="$(basename "${src_file}")"

        if skip_file "${filename}"; then
            printf '  SKIP  %s\n' "${src_file#"${SOURCE_DIR}/"}"
            continue
        fi

        # Derive destination path preserving subdirectory structure.
        local rel_path="${src_file#"${SOURCE_DIR}/"}"
        local dest_file="${DEST_DIR}/${rel_path}"

        # Export paths for the Python heredoc.
        export _MIGRATE_SRC="${src_file}"
        export _MIGRATE_DEST="${dest_file}"

        transform_file "${src_file}" "${dest_file}"

        printf '  OK    %s\n' "${rel_path}"

    done < <(find "${src_subdir}" -name '*.md' -print0 | sort -z)
}

# ---------------------------------------------------------------------------
# Summary: print name and entity_type from each migrated file
# ---------------------------------------------------------------------------

print_summary() {
    printf '\n--- Migration summary ---\n'
    printf '%-55s  %-35s  %s\n' 'FILE' 'name' 'entity_type'
    printf '%s\n' "$(printf '%.0s-' {1..120})"

    while IFS= read -r -d '' dest_file; do
        local rel="${dest_file#"${DEST_DIR}/"}"

        local name_val entity_type_val
        name_val="$(python3 -c "
import re, sys
with open('${dest_file}') as f:
    c = f.read()
m = re.search(r'^name:\s*(.+)$', c, re.MULTILINE)
print(m.group(1).strip() if m else '(none)')
")"
        entity_type_val="$(python3 -c "
import re, sys
with open('${dest_file}') as f:
    c = f.read()
m = re.search(r'^entity_type:\s*(.+)$', c, re.MULTILINE)
print(m.group(1).strip() if m else '(none)')
")"

        printf '%-55s  %-35s  %s\n' "${rel}" "${name_val}" "${entity_type_val}"

    done < <(find "${DEST_DIR}" -name '*.md' -print0 | sort -z)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    validate_environment

    printf 'Source : %s\n' "${SOURCE_DIR}"
    printf 'Dest   : %s\n' "${DEST_DIR}"
    printf '\n'

    mkdir -p "${DEST_DIR}"

    for subdir in "${SUBDIRS[@]}"; do
        migrate_directory "${subdir}"
    done

    print_summary
    printf '\nDone.\n'
}

main "$@"
