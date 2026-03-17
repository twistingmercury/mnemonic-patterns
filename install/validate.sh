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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

PATTERNS_DIR="${PATTERNS_DIR:-${SCRIPT_DIR}/../patterns}"

# shellcheck source=install/lib/print.sh
. "${SCRIPT_DIR}/lib/print.sh"

readonly VALID_LANGUAGES="agnostic bash c cpp csharp cql cypher dart delphi docker elixir erlang go json java javascript kotlin lua markdown matlab mql objective-c perl php plsql powershell python r react ruby rust scala shell sql swift toml tsql typescript visual-basic yaml zig"
readonly VALID_DOMAINS="api-design backend frontend testing devops cli data-design documentation data-access security shell-scripting configuration observability source-management"

readonly NAME_PATTERN='^[a-z][a-z0-9-]*$'
readonly NAME_MAX_LEN=128

readonly SKIP_FILES="README.md pattern-file-schema.md"

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dir)
                if [ -z "${2:-}" ]; then
                    print::error "--dir requires a path argument"
                    return 1
                fi
                PATTERNS_DIR="$2"
                shift 2
                ;;
            *)
                print::error "Unknown argument: $1"
                return 1
                ;;
        esac
    done
    return 0
}

check_dependencies() {
    local missing=0

    for cmd in yq jq; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            print::error "Required tool not found: ${cmd}"
            missing=$((missing + 1))
        fi
    done

    [ "${missing}" -eq 0 ] || return 1
    return 0
}

extract_frontmatter() {
    local file="$1"
    awk '/^---$/{flag=!flag; next} flag' "${file}"
}

parse_metadata() {
    local frontmatter="$1"
    printf "%s" "${frontmatter}" | yq eval -o=json '.'
}

in_list() {
    local value="$1"
    local list="$2"
    local word
    # Word splitting on ${list} is intentional — iterates space-separated tokens
    for word in ${list}; do
        [ "${value}" = "${word}" ] && return 0
    done
    return 1
}

should_skip() {
    local file="$1"
    local base
    base="$(basename "${file}")"
    in_list "${base}" "${SKIP_FILES}"
}

validate_pattern() {
    local file="$1"
    local errors=0

    print::info "Processing: ${file}"

    local frontmatter
    frontmatter="$(extract_frontmatter "${file}")"

    if [ -z "${frontmatter}" ]; then
        print::error "No YAML frontmatter found in ${file}"
        return 1
    fi

    local metadata
    if ! metadata="$(parse_metadata "${frontmatter}" 2>/dev/null)"; then
        print::error "Failed to parse YAML frontmatter in ${file}"
        return 1
    fi

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

    local name entity_type language domain description
    name="$(printf "%s" "${metadata}" | jq -r '.name // empty')"
    entity_type="$(printf "%s" "${metadata}" | jq -r '.entity_type // empty')"
    language="$(printf "%s" "${metadata}" | jq -r '.language // empty')"
    domain="$(printf "%s" "${metadata}" | jq -r '.domain // empty')"
    description="$(printf "%s" "${metadata}" | jq -r '.description // empty')"

    if ! printf "%s" "${name}" | grep -qE "${NAME_PATTERN}"; then
        print::error "Invalid name '${name}' in ${file}: must match ${NAME_PATTERN}"
        errors=$((errors + 1))
    fi

    if [ "${#name}" -gt "${NAME_MAX_LEN}" ]; then
        print::error "Invalid name '${name}' in ${file}: exceeds ${NAME_MAX_LEN} characters"
        errors=$((errors + 1))
    fi

    if ! printf "%s" "${entity_type}" | grep -qE "${NAME_PATTERN}"; then
        print::error "Invalid entity_type '${entity_type}' in ${file}: must be kebab-case (${NAME_PATTERN})"
        errors=$((errors + 1))
    fi

    if [ -z "${description}" ]; then
        print::error "Empty description in ${file}: description must be a non-empty string"
        errors=$((errors + 1))
    fi

    if ! in_list "${language}" "${VALID_LANGUAGES}"; then
        print::error "Invalid language '${language}' in ${file}: must be one of: ${VALID_LANGUAGES}"
        errors=$((errors + 1))
    fi

    if ! in_list "${domain}" "${VALID_DOMAINS}"; then
        print::error "Invalid domain '${domain}' in ${file}: must be one of: ${VALID_DOMAINS}"
        errors=$((errors + 1))
    fi

    if ! grep -qF '[//]: pattern' "${file}"; then
        print::error "No '[//]: pattern' decorators found in ${file}: at least one decorated section is required"
        errors=$((errors + 1))
    fi

    if ! grep -q '^## Overview' "${file}"; then
        print::error "Missing '## Overview' section in ${file}"
        errors=$((errors + 1))
    fi

    if [ "${errors}" -eq 0 ]; then
        print::success "Valid: ${name}"
        print::info "  Type: ${entity_type} | Language: ${language} | Domain: ${domain}"
        return 0
    fi

    return 1
}

validate_patterns_from_dir() {
    local dir="$1"

    if [ ! -d "${dir}" ]; then
        print::error "Patterns directory not found: ${dir}"
        return 1
    fi

    local total=0
    local passed=0
    local failed=0

    local file
    while IFS= read -r file; do
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
    done < <(find "${dir}" -name "*.md" -type f | sort)

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

main() {
    parse_args "$@" || exit 1

    if [ ! -d "${PATTERNS_DIR}" ]; then
        print::error "Patterns directory not found: ${PATTERNS_DIR}"
        exit 1
    fi
    PATTERNS_DIR="$(cd "${PATTERNS_DIR}" && pwd)"
    readonly PATTERNS_DIR

    check_dependencies || exit 1

    print::info "Mnemonic Pattern Validation"
    print::info "Scanning: ${PATTERNS_DIR}"
    printf "\n"

    if ! validate_patterns_from_dir "${PATTERNS_DIR}"; then
        exit 1
    fi
}

main "$@"
