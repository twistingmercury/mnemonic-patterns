#!/usr/bin/env bats
#
# validate.bats — Black-box tests for install/validate.sh
#
# Tests validate user-visible behaviour: exit codes, stdout/stderr content,
# and summary lines. No script internals are sourced or inspected.

VALIDATE_SCRIPT="${BATS_TEST_DIRNAME}/../install/validate.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Write a minimal, fully-valid pattern file to $1.
write_valid_pattern() {
    local file="$1"
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A test pattern for validation tests.' \
        '---' \
        '' \
        '# Test Pattern' \
        '' \
        '## Overview' \
        '' \
        'Overview content.' \
        '' \
        '[//]: pattern' \
        '' \
        '## Implementation' \
        '' \
        'Content.' \
        > "${file}"
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

setup() {
    export TEST_DIR="${BATS_TEST_TMPDIR}/test-$$"
    mkdir -p "${TEST_DIR}"
    export PATTERNS_DIR="${TEST_DIR}/patterns"
    mkdir -p "${PATTERNS_DIR}"
}

teardown() {
    rm -rf "${TEST_DIR}"
}

# ---------------------------------------------------------------------------
# Happy path
# ---------------------------------------------------------------------------

@test "validate - valid pattern file passes all checks" {
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "[SUCCESS] Valid: test-pattern"
}

@test "validate - valid pattern emits type language and domain info line" {
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "best-practice"
    printf '%s\n' "${output}" | grep -qF "go"
    printf '%s\n' "${output}" | grep -qF "backend"
}

@test "validate - summary shows Passed: 1 for a single valid file" {
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "Passed: 1"
    printf '%s\n' "${output}" | grep -qF "Failed: 0"
}

@test "validate - skips README.md and pattern-file-schema.md" {
    printf '%s\n' 'readme content' > "${PATTERNS_DIR}/README.md"
    printf '%s\n' 'schema content' > "${PATTERNS_DIR}/pattern-file-schema.md"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "Total: 1"
}

# ---------------------------------------------------------------------------
# Frontmatter errors
# ---------------------------------------------------------------------------

@test "validate - missing frontmatter fails" {
    printf '%s\n' '# No Frontmatter' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/no-front.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "frontmatter"
}

@test "validate - invalid YAML frontmatter fails" {
    printf '%s\n' \
        '---' \
        ': bad: yaml: [unclosed' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/bad-yaml.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "(frontmatter|parse)"
}

# ---------------------------------------------------------------------------
# Missing required fields — each individually
# ---------------------------------------------------------------------------

@test "validate - missing 'name' field fails" {
    printf '%s\n' \
        '---' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/no-name.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "name"
}

@test "validate - missing 'entity_type' field fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/no-entity-type.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "entity_type"
}

@test "validate - missing 'language' field fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/no-language.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "language"
}

@test "validate - missing 'domain' field fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/no-domain.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "domain"
}

@test "validate - missing 'description' field fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/no-description.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "description"
}

# ---------------------------------------------------------------------------
# Field value validation
# ---------------------------------------------------------------------------

@test "validate - name with underscores fails kebab-case check" {
    printf '%s\n' \
        '---' \
        'name: invalid_name' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/bad-name.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Invalid name"
}

@test "validate - name with uppercase letters fails kebab-case check" {
    printf '%s\n' \
        '---' \
        'name: InvalidName' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/upper-name.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Invalid name"
}

@test "validate - name exceeding 128 characters fails" {
    # Build a 129-character name: 'a' + 128 hyphens and letters
    local long_name
    long_name="a$(printf '%0.s-x' $(seq 1 64))"
    # Ensure it is longer than 128 chars and still kebab-case
    [ "${#long_name}" -gt 128 ] || long_name="${long_name}xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

    printf '%s\n' \
        '---' \
        "name: ${long_name}" \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/long-name.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "(exceeds|128)"
}

@test "validate - entity_type with uppercase letters fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: BestPractice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/bad-entity.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Invalid entity_type"
}

@test "validate - empty description fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        "description: ''" \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/empty-desc.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "description"
}

@test "validate - null description fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: null' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/null-desc.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "description"
}

@test "validate - invalid language value fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: golang' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/bad-lang.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Invalid language"
}

@test "validate - invalid domain value fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: not-a-domain' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/bad-domain.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Invalid domain"
}

# ---------------------------------------------------------------------------
# Body-structure validation
# ---------------------------------------------------------------------------

@test "validate - missing [//]: pattern decorator fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '## Section' \
        '' \
        'No decorator here.' \
        > "${PATTERNS_DIR}/no-decorator.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "pattern"
}

@test "validate - missing ## Overview section fails" {
    printf '%s\n' \
        '---' \
        'name: test-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '[//]: pattern' \
        '' \
        '## Implementation' \
        '' \
        'Content.' \
        > "${PATTERNS_DIR}/no-overview.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Overview"
}

# ---------------------------------------------------------------------------
# --dir flag behaviour
# ---------------------------------------------------------------------------

@test "validate - --dir with a valid directory runs correctly" {
    local alt_dir="${TEST_DIR}/alt-patterns"
    mkdir -p "${alt_dir}"
    write_valid_pattern "${alt_dir}/test-pattern.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${alt_dir}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "Passed: 1"
}

@test "validate - --dir with non-existent directory exits 1 with error" {
    run bash "${VALIDATE_SCRIPT}" --dir "/nonexistent/path/$$"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "not found"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

@test "validate - unknown argument prints error and exits 1" {
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}" --unknown-flag

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiF "Unknown argument"
}

# ---------------------------------------------------------------------------
# Summary and exit-code semantics
# ---------------------------------------------------------------------------

@test "validate - multiple invalid files reports correct failed count" {
    # Write two invalid files (no decorator)
    local i
    for i in 1 2; do
        printf '%s\n' \
            '---' \
            "name: bad-pattern-${i}" \
            'entity_type: best-practice' \
            'language: go' \
            'domain: backend' \
            'description: A description.' \
            '---' \
            '' \
            '## Overview' \
            '' \
            '## Section' \
            > "${PATTERNS_DIR}/bad-${i}.md"
    done

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "Failed: 2"
}

@test "validate - exit 0 when all files pass" {
    write_valid_pattern "${PATTERNS_DIR}/a.md"
    write_valid_pattern "${PATTERNS_DIR}/b.md"
    # Give them distinct names to avoid duplicate-name artefacts in output
    sed -i.bak 's/name: test-pattern/name: test-pattern-b/' "${PATTERNS_DIR}/b.md"
    rm -f "${PATTERNS_DIR}/b.md.bak"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
}

@test "validate - exit 1 when any file fails" {
    write_valid_pattern "${PATTERNS_DIR}/good.md"

    # A second file that is invalid (no decorator)
    printf '%s\n' \
        '---' \
        'name: bad-pattern' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A description.' \
        '---' \
        '' \
        '## Overview' \
        > "${PATTERNS_DIR}/bad.md"

    run bash "${VALIDATE_SCRIPT}" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
}
