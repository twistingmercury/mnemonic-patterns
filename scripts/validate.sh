#!/usr/bin/env bash
#
# validate.sh — Validate Mnemonic pattern .md files against the pattern schema.
#
# Usage:
#   validate.sh [--dir <path>]
#
# Environment:
#   PATTERNS_DIR   Directory to scan for pattern files (default: ../patterns
#                  relative to this script). Overridden by --dir.
#
# Dependencies:
#   yq (mikefarah/yq)   YAML parsing
#   jq                  JSON field extraction
#
# Exit codes:
#   0   All pattern files are valid
#   1   One or more pattern files failed validation

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve script directory
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR

# ---------------------------------------------------------------------------
# Source print library
# ---------------------------------------------------------------------------
# shellcheck source=../lib/print.sh
. "${SCRIPT_DIR}/../lib/print.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly VALID_LANGUAGES="agnostic bash c cpp csharp cql cypher dart delphi docker elixir erlang go json java javascript kotlin lua markdown matlab mql objective-c perl php plsql powershell python r react ruby rust scala shell sql swift toml tsql typescript visual-basic yaml zig"
readonly VALID_DOMAINS="api-design backend frontend testing devops cli data-design documentation data-access security shell-scripting configuration observability source-management"

readonly NAME_PATTERN='^[a-z][a-z0-9-]*$'
readonly NAME_MAX_LEN=128
readonly KEBAB_PATTERN='^[a-z][a-z0-9-]*$'

readonly SKIP_FILES="README.md pattern-file-schema.md"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    # Default: ../patterns relative to the script location
    PATTERNS_DIR="${PATTERNS_DIR:-${SCRIPT_DIR}/../patterns}"

    while [ $# -gt 0 ]; do
        case "$1" in
            --dir)
                if [ -z "${2:-}" ]; then
                    print::error "--dir requires a path argument"
                    exit 1
                fi
                PATTERNS_DIR="$2"
                shift 2
                ;;
            *)
                print::error "Unknown argument: $1"
                exit 1
                ;;
        esac
    done

    # Resolve to an absolute path
    PATTERNS_DIR="$(cd "${PATTERNS_DIR}" && pwd)"
    readonly PATTERNS_DIR
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extract YAML frontmatter (content between the first pair of --- markers).
extract_frontmatter() {
    local file="$1"
    awk '/^---$/{flag=!flag; next} flag' "${file}"
}

# Parse YAML frontmatter to JSON using mikefarah/yq.
parse_metadata() {
    local frontmatter="$1"
    printf "%s" "${frontmatter}" | yq eval -o=json '.'
}

# Return 0 if a value exists in a whitespace-separated word list.
in_list() {
    local value="$1"
    local list="$2"
    local word
    for word in ${list}; do
        [ "${value}" = "${word}" ] && return 0
    done
    return 1
}

# Return 0 if the file's basename is in the skip list.
should_skip() {
    local file="$1"
    local base
    base="$(basename "${file}")"
    in_list "${base}" "${SKIP_FILES}"
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Validate a single pattern file. Prints all errors found before returning.
# Returns 1 if any error was found, 0 otherwise.
validate_pattern() {
    local file="$1"
    local errors=0

    print::info "Processing: ${file}"

    # --- Frontmatter presence ---
    local frontmatter
    frontmatter="$(extract_frontmatter "${file}")"

    if [ -z "${frontmatter}" ]; then
        print::error "No YAML frontmatter found in ${file}"
        return 1
    fi

    # --- Parse to JSON ---
    local metadata
    if ! metadata="$(parse_metadata "${frontmatter}" 2>/dev/null)"; then
        print::error "Failed to parse YAML frontmatter in ${file}"
        return 1
    fi

    # --- Required field presence ---
    local required_fields="name entity_type language domain description"
    local missing=""
    local field
    for field in ${required_fields}; do
        if ! printf "%s" "${metadata}" | jq -e ".${field}" >/dev/null 2>&1; then
            missing="${missing} ${field}"
        fi
    done

    if [ -n "${missing}" ]; then
        # Trim leading space
        print::error "Missing required fields in ${file}:${missing}"
        # Cannot validate field values without the fields present
        return 1
    fi

    # --- Extract field values ---
    local name entity_type language domain
    name="$(printf "%s" "${metadata}" | jq -r '.name')"
    entity_type="$(printf "%s" "${metadata}" | jq -r '.entity_type')"
    language="$(printf "%s" "${metadata}" | jq -r '.language')"
    domain="$(printf "%s" "${metadata}" | jq -r '.domain')"

    # --- Validate: name format ---
    if ! printf "%s" "${name}" | grep -qE "${NAME_PATTERN}"; then
        print::error "Invalid name '${name}' in ${file}: must match ${NAME_PATTERN}"
        errors=$((errors + 1))
    fi

    if [ "${#name}" -gt "${NAME_MAX_LEN}" ]; then
        print::error "Invalid name '${name}' in ${file}: exceeds ${NAME_MAX_LEN} characters"
        errors=$((errors + 1))
    fi

    # --- Validate: entity_type format ---
    if ! printf "%s" "${entity_type}" | grep -qE "${KEBAB_PATTERN}"; then
        print::error "Invalid entity_type '${entity_type}' in ${file}: must be kebab-case (${KEBAB_PATTERN})"
        errors=$((errors + 1))
    fi

    # --- Validate: language value ---
    if ! in_list "${language}" "${VALID_LANGUAGES}"; then
        print::error "Invalid language '${language}' in ${file}: must be one of: ${VALID_LANGUAGES}"
        errors=$((errors + 1))
    fi

    # --- Validate: domain value ---
    if ! in_list "${domain}" "${VALID_DOMAINS}"; then
        print::error "Invalid domain '${domain}' in ${file}: must be one of: ${VALID_DOMAINS}"
        errors=$((errors + 1))
    fi

    # --- Validate: body structure ---
    # Check for at least one H2 section
    if ! grep -q '^## ' "${file}"; then
        print::error "No H2 sections (## ) found in ${file}: at least one is required"
        errors=$((errors + 1))
    fi

    # Check for ## Overview section
    if ! grep -q '^## Overview' "${file}"; then
        print::error "Missing '## Overview' section in ${file}"
        errors=$((errors + 1))
    fi

    # --- Report success ---
    if [ "${errors}" -eq 0 ]; then
        print::success "Valid: ${name}"
        print::info "  Type: ${entity_type} | Language: ${language} | Domain: ${domain}"
        return 0
    fi

    return 1
}

# ---------------------------------------------------------------------------
# Directory scan
# ---------------------------------------------------------------------------

validate_patterns_from_dir() {
    local dir="$1"

    if [ ! -d "${dir}" ]; then
        print::error "Patterns directory not found: ${dir}"
        return 1
    fi

    local total=0
    local passed=0
    local failed=0

    # Use find with -print0 / read -d '' for filenames with spaces
    while IFS= read -r -d '' file; do
        if should_skip "${file}"; then
            continue
        fi

        total=$((total + 1))

        if validate_pattern "${file}"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi

        # Blank line between files for readability
        printf "\n"
    done < <(find "${dir}" -name "*.md" -type f -print0 | sort -z)

    print::info "Summary:"
    print::info "  Total: ${total}"
    print::success "  Passed: ${passed}"

    if [ "${failed}" -gt 0 ]; then
        print::error "  Failed: ${failed}"
        return 1
    fi

    print::info "  Failed: 0"
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    parse_args "$@"

    print::info "Mnemonic Pattern Validation"
    print::info "Scanning: ${PATTERNS_DIR}"
    printf "\n"

    if ! validate_patterns_from_dir "${PATTERNS_DIR}"; then
        exit 1
    fi
}

main "$@"
