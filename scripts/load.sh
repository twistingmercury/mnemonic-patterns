#!/usr/bin/env bash
# load.sh — Load pattern files into the Mnemonic Admin API.
#
# Usage:
#   ./scripts/load.sh [--server <url>] [--dir <path>]
#
# Environment variables (override with flags):
#   MNEMONIC_BASE_URL   API base URL (default: http://localhost:8080)
#   PATTERNS_DIR        Directory containing pattern markdown files
#                       (default: ./patterns relative to script location)
#
# Dependencies: curl, yq (mikefarah/yq), jq

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve script directory
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# ---------------------------------------------------------------------------
# Source print library
# ---------------------------------------------------------------------------
# shellcheck source=/Users/doublej/dev/mnemonic-patterns/lib/print.sh
. "${SCRIPT_DIR}/../lib/print.sh"

# ---------------------------------------------------------------------------
# Defaults (overridable via env or flags)
# ---------------------------------------------------------------------------
MNEMONIC_BASE_URL="${MNEMONIC_BASE_URL:-http://localhost:8080}"
PATTERNS_DIR="${PATTERNS_DIR:-${SCRIPT_DIR}/../patterns}"

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
COUNT_TOTAL=0
COUNT_LOADED=0
COUNT_SKIPPED=0
COUNT_FAILED=0

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --server)
                [ "$#" -ge 2 ] || { print::error "--server requires an argument"; return 1; }
                MNEMONIC_BASE_URL="$2"
                shift 2
                ;;
            --dir)
                [ "$#" -ge 2 ] || { print::error "--dir requires an argument"; return 1; }
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

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
    local missing=0

    for cmd in curl yq jq; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            print::error "Required tool not found: ${cmd}"
            missing=$((missing + 1))
        fi
    done

    [ "${missing}" -eq 0 ] || return 1
    return 0
}

# ---------------------------------------------------------------------------
# Environment validation
# ---------------------------------------------------------------------------
validate_environment() {
    if [ ! -d "${PATTERNS_DIR}" ]; then
        print::error "Patterns directory not found: ${PATTERNS_DIR}"
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Run validate.sh before loading
# ---------------------------------------------------------------------------
run_validation() {
    local validate_script="${SCRIPT_DIR}/validate.sh"

    if [ ! -f "${validate_script}" ]; then
        print::error "validate.sh not found at: ${validate_script}"
        return 1
    fi

    print::info "Running validation first..."

    if ! bash "${validate_script}"; then
        print::error "Validation failed — aborting load"
        return 1
    fi

    print::success "Validation passed"
    return 0
}

# ---------------------------------------------------------------------------
# Frontmatter extraction helpers
# ---------------------------------------------------------------------------

# Extract the raw YAML frontmatter block (content between first two --- markers)
extract_frontmatter() {
    local file="${1}"
    awk 'BEGIN { found=0; done=0 }
         /^---/ {
             if (found == 0) { found=1; next }
             else { done=1; exit }
         }
         found == 1 && done == 0 { print }
    ' "${file}"
}

# Extract the body: everything after the closing --- of frontmatter
extract_body() {
    local file="${1}"
    awk 'BEGIN { delimiters=0; found=0 }
         /^---/ {
             delimiters++
             if (delimiters == 2) { found=1; next }
             next
         }
         found == 1 { print }
    ' "${file}"
}

# ---------------------------------------------------------------------------
# Build JSON tags array from frontmatter JSON
# ---------------------------------------------------------------------------
build_tags_json() {
    local frontmatter_json="${1}"
    printf '%s' "${frontmatter_json}" \
        | jq 'if .tags == null then [] else .tags end'
}

# ---------------------------------------------------------------------------
# Build agent_associations array from frontmatter JSON
# ---------------------------------------------------------------------------
build_agent_associations_json() {
    local frontmatter_json="${1}"
    printf '%s' "${frontmatter_json}" \
        | jq 'if .agents == null then [] else [ .agents[] | {"agent_name": ., "relevance": 0.8} ] end'
}

# ---------------------------------------------------------------------------
# POST a single pattern file
# ---------------------------------------------------------------------------
load_pattern() {
    local file="${1}"
    local base_name
    base_name="$(basename "${file}")"

    # Skip reserved filenames
    if [ "${base_name}" = "README.md" ] || [ "${base_name}" = "pattern-file-schema.md" ]; then
        return 0
    fi

    COUNT_TOTAL=$((COUNT_TOTAL + 1))
    print::info "Processing: ${file#"${SCRIPT_DIR}/../"}"

    # --- Extract and parse frontmatter ---
    local raw_frontmatter
    raw_frontmatter="$(extract_frontmatter "${file}")"

    if [ -z "${raw_frontmatter}" ]; then
        print::error "No frontmatter found in: ${file}"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return 0
    fi

    local frontmatter_json
    if ! frontmatter_json="$(printf '%s\n' "${raw_frontmatter}" | yq eval -o=json '.')"; then
        print::error "Failed to parse frontmatter in: ${file}"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return 0
    fi

    # --- Extract scalar fields ---
    local name description entity_type language domain
    name="$(printf '%s' "${frontmatter_json}"        | jq -r '.name        // empty')"
    description="$(printf '%s' "${frontmatter_json}" | jq -r '.description // empty')"
    entity_type="$(printf '%s' "${frontmatter_json}" | jq -r '.entity_type // empty')"
    language="$(printf '%s' "${frontmatter_json}"    | jq -r '.language    // empty')"
    domain="$(printf '%s' "${frontmatter_json}"      | jq -r '.domain      // empty')"

    if [ -z "${name}" ]; then
        print::error "Missing required frontmatter field 'name' in: ${file}"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return 0
    fi

    # --- Build array fields ---
    local tags_json agent_assoc_json
    tags_json="$(build_tags_json "${frontmatter_json}")"
    agent_assoc_json="$(build_agent_associations_json "${frontmatter_json}")"

    # --- Extract body content ---
    local content
    content="$(extract_body "${file}")"

    # --- Build request payload ---
    local payload
    payload="$(jq -n \
        --arg     name                "${name}" \
        --arg     description         "${description}" \
        --arg     entity_type         "${entity_type}" \
        --arg     language            "${language}" \
        --arg     domain              "${domain}" \
        --argjson tags                "${tags_json}" \
        --argjson agent_associations  "${agent_assoc_json}" \
        --arg     content             "${content}" \
        '{
            name:                $name,
            description:         $description,
            entity_type:         $entity_type,
            language:            $language,
            domain:              $domain,
            tags:                $tags,
            agent_associations:  $agent_associations,
            content:             $content
        }')"

    # --- POST to API; capture status and body separately ---
    local api_url="${MNEMONIC_BASE_URL}/v1/api/patterns"
    local http_status response_body tmp_body
    tmp_body="$(mktemp)"

    if ! http_status="$(curl -sS \
        -o "${tmp_body}" \
        -w '%{http_code}' \
        -X POST \
        -H 'Content-Type: application/json' \
        -d "${payload}" \
        "${api_url}" 2>&1)"; then
        rm -f "${tmp_body}"
        print::error "Failed to load ${name}: curl error"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return 0
    fi

    response_body="$(cat "${tmp_body}")"
    rm -f "${tmp_body}"

    # --- Interpret response ---
    case "${http_status}" in
        202)
            print::success "Loaded: ${name}"
            COUNT_LOADED=$((COUNT_LOADED + 1))
            ;;
        409)
            print::warning "Already exists, skipping: ${name}"
            COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
            ;;
        *)
            print::error "Failed to load ${name}: HTTP ${http_status}"
            if [ -n "${response_body}" ]; then
                print::error "  Response: ${response_body}"
            fi
            COUNT_FAILED=$((COUNT_FAILED + 1))
            ;;
    esac

    return 0
}

# ---------------------------------------------------------------------------
# Walk the patterns directory and load each markdown file
# ---------------------------------------------------------------------------
load_all_patterns() {
    local patterns_dir
    patterns_dir="$(cd "${PATTERNS_DIR}" && pwd)"

    print::info "Loading patterns from: ${patterns_dir}"

    local pattern_file
    while IFS= read -r pattern_file; do
        load_pattern "${pattern_file}"
    done < <(find "${patterns_dir}" -type f -name "*.md" | sort)

    return 0
}

# ---------------------------------------------------------------------------
# Print summary
# ---------------------------------------------------------------------------
print_summary() {
    print::info "Summary:"
    print::info "  Total: ${COUNT_TOTAL}"
    print::success "  Loaded: ${COUNT_LOADED}"
    print::warning "  Skipped (already exist): ${COUNT_SKIPPED}"
    print::error "  Failed: ${COUNT_FAILED}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"

    check_dependencies   || exit 1
    validate_environment || exit 1
    run_validation       || exit 1

    load_all_patterns

    print_summary

    if [ "${COUNT_FAILED}" -gt 0 ]; then
        exit 1
    fi

    exit 0
}

main "$@"
