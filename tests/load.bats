#!/usr/bin/env bats
#
# load.bats — Black-box tests for install/load.sh
#
# Strategy
# --------
# load.sh resolves validate.sh and lib/print.sh relative to its own SCRIPT_DIR.
# Every test therefore runs a *copy* of load.sh placed in a temporary install
# directory (TMP_INSTALL_DIR) alongside a controllable validate.sh stub and the
# real print.sh.  curl is stubbed by placing a fake binary at the front of PATH.
# No internals of load.sh are sourced.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Write a minimal, fully-valid pattern markdown file to $1.
# Optional $2 overrides the name field (default: test-pattern).
write_valid_pattern() {
    local file="$1"
    local name="${2:-test-pattern}"
    printf '%s\n' \
        '---' \
        "name: ${name}" \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: A test pattern for load tests.' \
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

# Write a curl stub that exits 0 and emits $2 as the HTTP status code on stdout.
# load.sh captures the -w '%{http_code}' output via command substitution, so the
# stub only needs to print the status code.  It also creates the -o temp file.
write_curl_stub() {
    local stub="$1"
    local http_code="${2:-202}"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'output_file=""' \
        'i=1' \
        'while [ "$i" -le "$#" ]; do' \
        '    arg="$(eval printf '"'"'%s'"'"' "\${$i}")"' \
        '    if [ "$arg" = "-o" ]; then' \
        '        i=$((i+1))' \
        '        output_file="$(eval printf '"'"'%s'"'"' "\${$i}")"' \
        '    fi' \
        '    i=$((i+1))' \
        'done' \
        '[ -n "$output_file" ] && : > "$output_file"' \
        "printf '%s' '${http_code}'" \
        > "${stub}"
    chmod +x "${stub}"
}

# Write a curl stub that exits non-zero (simulates a network error).
write_curl_error_stub() {
    local stub="$1"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        'exit 6' \
        > "${stub}"
    chmod +x "${stub}"
}

# Write a curl stub that records all arguments to $2, then succeeds with 202.
write_curl_recording_stub() {
    local stub="$1"
    local record="$2"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        "printf '%s\n' \"\$*\" >> \"${record}\"" \
        'output_file=""' \
        'i=1' \
        'while [ "$i" -le "$#" ]; do' \
        '    arg="$(eval printf '"'"'%s'"'"' "\${$i}")"' \
        '    if [ "$arg" = "-o" ]; then' \
        '        i=$((i+1))' \
        '        output_file="$(eval printf '"'"'%s'"'"' "\${$i}")"' \
        '    fi' \
        '    i=$((i+1))' \
        'done' \
        '[ -n "$output_file" ] && : > "$output_file"' \
        "printf '202'" \
        > "${stub}"
    chmod +x "${stub}"
}

# Write a validate.sh stub that always succeeds silently.
write_validate_pass_stub() {
    local stub="$1"
    printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "${stub}"
    chmod +x "${stub}"
}

# Write a validate.sh stub that records its arguments to $2 and exits 0.
write_validate_recording_stub() {
    local stub="$1"
    local record="$2"
    printf '%s\n' \
        '#!/usr/bin/env bash' \
        "printf '%s\n' \"\$*\" >> \"${record}\"" \
        'exit 0' \
        > "${stub}"
    chmod +x "${stub}"
}

# Populate TMP_INSTALL_DIR with:
#   load.sh (copy of real)
#   validate.sh (stub — must be created separately after this call)
#   lib/print.sh (copy of real)
setup_install_dir() {
    cp "${BATS_TEST_DIRNAME}/../install/load.sh"     "${TMP_INSTALL_DIR}/load.sh"
    cp "${BATS_TEST_DIRNAME}/../install/lib/print.sh" "${TMP_INSTALL_DIR}/lib/print.sh"
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

setup() {
    export TEST_DIR="${BATS_TEST_TMPDIR}/test-$$"
    export BIN_DIR="${TEST_DIR}/bin"
    export PATTERNS_DIR="${TEST_DIR}/patterns"
    export TMP_INSTALL_DIR="${TEST_DIR}/install"

    mkdir -p "${BIN_DIR}" "${PATTERNS_DIR}" "${TMP_INSTALL_DIR}/lib"

    # Populate the install directory with load.sh and print.sh.
    setup_install_dir

    # Default: validate stub that always passes.
    write_validate_pass_stub "${TMP_INSTALL_DIR}/validate.sh"

    # Default: curl stub returning 202.
    write_curl_stub "${BIN_DIR}/curl" "202"

    # Delegate yq and jq to real binaries so frontmatter parsing works.
    local real_yq real_jq
    real_yq="$(command -v yq)"
    real_jq="$(command -v jq)"
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "${real_yq}" > "${BIN_DIR}/yq"
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "${real_jq}" > "${BIN_DIR}/jq"
    chmod +x "${BIN_DIR}/yq" "${BIN_DIR}/jq"

    export ORIGINAL_PATH="${PATH}"
    export PATH="${BIN_DIR}:${PATH}"
}

teardown() {
    export PATH="${ORIGINAL_PATH}"
    rm -rf "${TEST_DIR}"
}

# Convenience: run load.sh from the temp install directory.
run_load() {
    run bash "${TMP_INSTALL_DIR}/load.sh" "$@"
}

# ---------------------------------------------------------------------------
# Dependency checks
#
# Strategy: for each "missing X" test, build a shadow /usr/bin directory that
# contains symlinks to every binary in /usr/bin EXCEPT the one under test.
# This lets the script's check_dependencies call fail for exactly that tool
# while keeping all coreutils (awk, find, sort, dirname …) available.
# yq and jq live in /usr/local/bin; they are handled by stubs in BIN_DIR.
# ---------------------------------------------------------------------------

# Create a shadow directory that mirrors /usr/bin minus $1.
# Prints the path of the created shadow directory.
make_shadow_usr_bin_without() {
    local omit="$1"
    local shadow="${TEST_DIR}/shadow-usr-bin-no-${omit}"
    mkdir -p "${shadow}"
    local f
    for f in /usr/bin/*; do
        local name
        name="$(basename "${f}")"
        [ "${name}" = "${omit}" ] && continue
        ln -sf "${f}" "${shadow}/${name}" 2>/dev/null || true
    done
    printf '%s' "${shadow}"
}

@test "load - missing curl prints error and exits 1" {
    local shadow
    shadow="$(make_shadow_usr_bin_without curl)"

    local hbin="${TEST_DIR}/hbin-no-curl"
    mkdir -p "${hbin}"
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$(command -v yq)" > "${hbin}/yq"
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$(command -v jq)" > "${hbin}/jq"
    chmod +x "${hbin}/yq" "${hbin}/jq"

    # shadow replaces /usr/bin; hbin provides yq+jq; no curl anywhere
    export PATH="${hbin}:${shadow}:/usr/local/bin:/bin:/usr/sbin"

    run bash "${TMP_INSTALL_DIR}/load.sh" --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "curl"
}

@test "load - missing yq prints error and exits 1" {
    # yq lives in /usr/local/bin; shadow that dir by providing only curl+jq stubs
    local hbin="${TEST_DIR}/hbin-no-yq"
    mkdir -p "${hbin}"
    cp "${BIN_DIR}/curl" "${hbin}/curl"
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$(command -v jq)" > "${hbin}/jq"
    chmod +x "${hbin}/jq"

    # Prepend hbin BEFORE the directories that hold yq and jq
    export PATH="${hbin}:/usr/bin:/bin:/usr/sbin"

    run bash "${TMP_INSTALL_DIR}/load.sh" --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "yq"
}

@test "load - missing jq prints error and exits 1" {
    local hbin="${TEST_DIR}/hbin-no-jq"
    mkdir -p "${hbin}"
    cp "${BIN_DIR}/curl" "${hbin}/curl"
    printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$(command -v yq)" > "${hbin}/yq"
    chmod +x "${hbin}/yq"

    export PATH="${hbin}:/usr/bin:/bin:/usr/sbin"

    run bash "${TMP_INSTALL_DIR}/load.sh" --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "jq"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

@test "load - unknown argument prints error and exits 1" {
    run_load --dir "${PATTERNS_DIR}" --not-a-flag

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "Unknown argument"
}

@test "load - --server without a value prints error and exits 1" {
    run_load --server

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "server requires"
}

@test "load - --dir without a value prints error and exits 1" {
    run_load --dir

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qiE "dir requires"
}

# ---------------------------------------------------------------------------
# --server sets the API URL used in the curl call
# ---------------------------------------------------------------------------

@test "load - --server sets the API URL forwarded to curl" {
    local record_file="${TEST_DIR}/curl-args.txt"
    write_curl_recording_stub "${BIN_DIR}/curl" "${record_file}"

    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://test-server:1234" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    grep -qF "http://test-server:1234" "${record_file}"
}

# ---------------------------------------------------------------------------
# --dir flag
# ---------------------------------------------------------------------------

@test "load - --dir sets the patterns directory scanned for files" {
    local alt_dir="${TEST_DIR}/alt-patterns"
    mkdir -p "${alt_dir}"
    write_valid_pattern "${alt_dir}/alt-pattern.md" "alt-pattern"

    run_load --server "http://localhost:9999" --dir "${alt_dir}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "alt-pattern"
}

# ---------------------------------------------------------------------------
# validate.sh invocation
# ---------------------------------------------------------------------------

@test "load - validate.sh is invoked with --dir matching the patterns directory" {
    local record_file="${TEST_DIR}/validate-args.txt"
    write_validate_recording_stub "${TMP_INSTALL_DIR}/validate.sh" "${record_file}"

    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    grep -qF -- "--dir" "${record_file}"
    grep -qF "${PATTERNS_DIR}" "${record_file}"
}

# ---------------------------------------------------------------------------
# Per-pattern failure modes (validate stub passes; load_pattern fails)
# ---------------------------------------------------------------------------

@test "load - pattern with missing frontmatter increments COUNT_FAILED and does not abort" {
    # File has no frontmatter — load_pattern detects this independently of validate.sh
    printf '%s\n' '# No Frontmatter' '' '## Overview' > "${PATTERNS_DIR}/aa-no-front.md"
    # Valid file sorted after so both are processed
    write_valid_pattern "${PATTERNS_DIR}/bb-valid.md" "bb-valid-pattern"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "Failed: 1"
    # The valid pattern was loaded (run not aborted)
    printf '%s\n' "${output}" | grep -qF "Loaded: 1"
}

@test "load - pattern with missing name field increments COUNT_FAILED and does not abort" {
    printf '%s\n' \
        '---' \
        'entity_type: best-practice' \
        'language: go' \
        'domain: backend' \
        'description: Missing name.' \
        '---' \
        '' \
        '## Overview' \
        '' \
        '[//]: pattern' \
        '' \
        '## Section' \
        > "${PATTERNS_DIR}/aa-no-name.md"
    write_valid_pattern "${PATTERNS_DIR}/bb-valid.md" "bb-valid-pattern"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "Failed: 1"
    printf '%s\n' "${output}" | grep -qF "Loaded: 1"
}

# ---------------------------------------------------------------------------
# HTTP response codes
# ---------------------------------------------------------------------------

@test "load - HTTP 202 response increments COUNT_LOADED" {
    write_curl_stub "${BIN_DIR}/curl" "202"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qF "Loaded: 1"
}

@test "load - HTTP 409 response increments COUNT_SKIPPED" {
    write_curl_stub "${BIN_DIR}/curl" "409"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
    printf '%s\n' "${output}" | grep -qiF "Skipped"
}

@test "load - HTTP 500 response increments COUNT_FAILED" {
    write_curl_stub "${BIN_DIR}/curl" "500"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "Failed: 1"
}

@test "load - curl error increments COUNT_FAILED" {
    write_curl_error_stub "${BIN_DIR}/curl"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
    printf '%s\n' "${output}" | grep -qF "Failed: 1"
}

# ---------------------------------------------------------------------------
# Exit-code semantics
# ---------------------------------------------------------------------------

@test "load - exits 0 when no failures" {
    write_curl_stub "${BIN_DIR}/curl" "202"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 0 ]
}

@test "load - exits 1 when any failures occur" {
    write_curl_stub "${BIN_DIR}/curl" "500"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    run_load --server "http://localhost:9999" --dir "${PATTERNS_DIR}"

    [ "${status}" -eq 1 ]
}

# ---------------------------------------------------------------------------
# print_summary stderr behaviour
# ---------------------------------------------------------------------------

@test "load - print_summary emits nothing to stderr on a clean run" {
    write_curl_stub "${BIN_DIR}/curl" "202"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    local stderr_file="${TEST_DIR}/stderr.txt"
    run bash -c "bash '${TMP_INSTALL_DIR}/load.sh' \
        --server 'http://localhost:9999' \
        --dir '${PATTERNS_DIR}' 2>'${stderr_file}'"

    local stderr_content
    stderr_content="$(cat "${stderr_file}")"
    [ -z "${stderr_content}" ]
}

@test "load - print_summary emits error line to stderr when COUNT_FAILED is greater than 0" {
    write_curl_stub "${BIN_DIR}/curl" "500"
    write_valid_pattern "${PATTERNS_DIR}/test-pattern.md"

    local stderr_file="${TEST_DIR}/stderr.txt"
    run bash -c "bash '${TMP_INSTALL_DIR}/load.sh' \
        --server 'http://localhost:9999' \
        --dir '${PATTERNS_DIR}' 2>'${stderr_file}'"

    local stderr_content
    stderr_content="$(cat "${stderr_file}")"
    [ -n "${stderr_content}" ]
    printf '%s\n' "${stderr_content}" | grep -qiE "Failed"
}
